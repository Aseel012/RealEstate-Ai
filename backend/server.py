"""
ESTAT·IQ — Local Python Backend
Run with: python server.py
Then expose with: ngrok http 5000
Paste the ngrok URL into AppConfig.ngrokBase in the Flutter app.

Endpoints:
  POST /new-lead          → saves to Sheet1 + Bland.ai call + Twilio SMS
  POST /trigger-call      → manually fire Bland.ai call for a phone number
  POST /book-appointment  → saves to Appointments sheet + Twilio SMS
  GET  /health            → connectivity check
"""

import os, json, logging, traceback, gspread, requests
from flask import Flask, request, jsonify
from oauth2client.service_account import ServiceAccountCredentials
from twilio.rest import Client as TwilioClient
from datetime import datetime
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

# ─── CONFIG ───────────────────────────────────────────────────────────────────
TWILIO_SID       = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
TWILIO_TOKEN     = 'xxxxxxxxxxxxxxxxxxxxxxxxx'
TWILIO_FROM      = '+Xxxxxxxxxxx'
BLAND_API_KEY    = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
SPREADSHEET_ID   = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
CREDS_FILE       = os.path.join(os.path.dirname(__file__), 'credentials.json')

# ─── GOOGLE SHEETS ─────────────────────────────────────────────────────────────
def get_sheets_client():
    scope = [
        'https://spreadsheets.google.com/feeds',
        'https://www.googleapis.com/auth/drive',
    ]
    creds = ServiceAccountCredentials.from_json_keyfile_name(CREDS_FILE, scope)
    return gspread.authorize(creds)

def ensure_sheet_setup():
    """Ensure all required tabs exist in the spreadsheet."""
    try:
        gc = get_sheets_client()
        ss = gc.open_by_key(SPREADSHEET_ID)
        existing = [w.title for w in ss.worksheets()]
        
        # Sheet1 (Leads)
        if 'Sheet1' not in existing:
            ws = ss.add_worksheet('Sheet1', 100, 20)
            ws.append_row(['Timestamp','Full Name','Phone','Location','Property Type','Budget','Source'])
            log.info("Created 'Sheet1' tab")
            
        # calling
        if 'calling' not in existing:
            ws = ss.add_worksheet('calling', 100, 20)
            ws.append_row(['Timestamp','Full Name','Phone','Call Status','Duration','Bot Summary','Next Action'])
            log.info("Created 'calling' tab")
            
        # Appointments
        if 'Appointments' not in existing:
            ws = ss.add_worksheet('Appointments', 100, 20)
            ws.append_row(['Timestamp','Full Name','Phone','Appointment Date','Appointment Time','Location','Property Type','Budget','Status','Notes'])
            log.info("Created 'Appointments' tab")
            
        return True
    except Exception as e:
        log.error(f"Sheet setup failed: {e}")
        return False

def ensure_headers(ws, headers):
    """Make sure row 1 has the correct headers."""
    try:
        row1 = ws.row_values(1)
        if not row1 or row1[0] == '':
            ws.insert_row(headers, 1)
    except Exception:
        ws.insert_row(headers, 1)
def append_lead(data):
    """Write one row to Sheet1."""
    gc = get_sheets_client()
    ss = gc.open_by_key(SPREADSHEET_ID)
    ws = ss.worksheet('Sheet1')
    ensure_headers(ws, ['Timestamp','Full Name','Phone','Location','Property Type','Budget','Source'])
    ws.append_row([
        datetime.utcnow().isoformat(),
        data.get('full_name', ''),
        data.get('phone', ''),
        data.get('location', ''),
        data.get('property_type', ''),
        data.get('price_range', ''),
        data.get('source', 'flutter_app'),
    ], value_input_option='RAW')

def find_lead_by_phone(phone_digits):
    """Search Sheet1 for a lead matching the last 10 digits of the phone."""
    try:
        gc = get_sheets_client()
        ss = gc.open_by_key(SPREADSHEET_ID)
        ws = ss.worksheet('Sheet1')
        records = ws.get_all_records()
        
        # Search for matching phone (last 10 digits to be safe)
        target = phone_digits[-10:]
        for r in reversed(records): # Start from newest
            r_phone = "".join(filter(str.isdigit, str(r.get('Phone', ''))))
            if r_phone.endswith(target):
                return r
    except Exception as e:
        log.warning(f'Could not search for lead: {e}')
    return None

def append_calling(data, status='Initiated'):
    """Write one row to calling sheet."""
    try:
        gc = get_sheets_client()
        ss = gc.open_by_key(SPREADSHEET_ID)
        ws = ss.worksheet('calling')
        ensure_headers(ws, ['Timestamp','Full Name','Phone','Call Status','Duration','Bot Summary','Next Action'])
        ws.append_row([
            datetime.utcnow().isoformat(),
            data.get('full_name', ''),
            data.get('phone', ''),
            status,
            '-',
            'AI call triggered via ESTAT·IQ',
            'Await response',
        ], value_input_option='RAW')
    except Exception as e:
        log.warning(f'Could not write to calling sheet: {e}')

def append_appointment(data):
    """Write one row to Appointments sheet."""
    gc = get_sheets_client()
    ss = gc.open_by_key(SPREADSHEET_ID)
    ws = ss.worksheet('Appointments')
    ensure_headers(ws, ['Timestamp','Full Name','Phone','Appointment Date','Appointment Time','Location','Property Type','Budget','Status','Notes'])
    ws.append_row([
        datetime.utcnow().isoformat(),
        data.get('full_name', ''),
        data.get('phone', ''),
        data.get('appointment_date', ''),
        data.get('appointment_time', ''),
        data.get('location', ''),
        data.get('property_type', ''),
        data.get('budget', ''),
        'Confirmed',
        data.get('notes', ''),
    ], value_input_option='RAW')

# ─── BLAND.AI ──────────────────────────────────────────────────────────────────
def fire_bland_call(phone, name, location, property_type, budget):
    """Trigger an outbound AI call via Bland.ai."""
    # ─── Robust Phone Normalization ──────────────────────────────────────────
    # 1. Strip all non-digits
    digits = "".join(filter(str.isdigit, str(phone)))
    # 2. If it starts with 91 and has > 10 digits, treat as +91
    if digits.startswith('91') and len(digits) > 10:
        digits = digits[2:]
    # 3. Final format must be +91XXXXXXXXXX
    phone_clean = f'+91{digits}'

    log.info(f'[Bland.ai] Attempting call to {phone_clean} for {name}')

    payload = {
        "phone_number": phone_clean,
        "task": (
            f"You are a friendly real estate assistant for ESTAT·IQ. "
            f"You are calling {name} who is looking for a {property_type} in {location} "
            f"with a budget of {budget}. "
            "Greet them warmly in Hindi or English based on how they respond. "
            "Confirm their requirements, ask about preferred size and when they would like a site visit. "
            "Be helpful, human-like. Keep the call under 3 minutes."
        ),
        "voice": "maya", # Switched to a standard high-quality Bland.ai voice
        "language": "en-IN", # Explicitly set language/accent
        "reduce_latency": True,
        "record": True,
        "max_duration": 3,
        "answered_by_enabled": True,
    }
    headers = {
        "authorization": BLAND_API_KEY,
        "Content-Type": "application/json",
    }
    log.info(f"[Bland.ai] Calling out... Auth Key Prefix: {BLAND_API_KEY[:10]}...")
    try:
        r = requests.post(
            "https://api.bland.ai/v1/calls", 
            json=payload, 
            headers=headers, 
            timeout=30 # Increased timeout
        )
        log.info(f"[Bland.ai] RAW RESPONSE: {r.status_code} - {r.text}")
        
        if r.status_code == 200:
            log.info(f"[Bland.ai] SUCCESS! Call ID: {r.json().get('call_id')}")
            return r.json()
        else:
            log.error(f"[Bland.ai] SERVER REJECTED CALL (HTTP {r.status_code}): {r.text}")
            raise Exception(f"Bland.ai Error: {r.text}")
    except requests.exceptions.RequestException as e:
        log.error(f"[Bland.ai] CONNECTION FAILED: {e}")
        raise Exception(f"Failed to connect to Bland.ai: {str(e)}")

# ─── TWILIO SMS ────────────────────────────────────────────────────────────────
def send_sms(to_phone, message):
    """Send an SMS via Twilio."""
    try:
        # ─── Safe Phone Normalization ───
        digits = "".join(filter(str.isdigit, str(to_phone)))
        if digits.startswith('91') and len(digits) > 10:
            digits = digits[2:]
        phone_clean = f'+91{digits}'
        
        twilio = TwilioClient(TWILIO_SID, TWILIO_TOKEN)
        msg = twilio.messages.create(to=phone_clean, from_=TWILIO_FROM, body=message)
        log.info(f'[Twilio SMS] sent → {msg.sid}')
        return True
    except Exception as e:
        log.warning(f'[Twilio SMS] failed: {e}')
        return False

# ─── ROUTES ────────────────────────────────────────────────────────────────────

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'server': 'ESTAT·IQ Backend'}), 200


@app.route('/new-lead', methods=['POST'])
def new_lead():
    """
    Called by Flutter when a user submits an inquiry.
    1. Saves to Sheet1
    2. Sends Twilio SMS confirmation
    3. Fires Bland.ai AI call
    """
    data = request.get_json(force=True) or {}
    log.info(f'[/new-lead] RECEIVED: {data}')

    name          = data.get('full_name', '').strip()
    phone         = data.get('phone', '').strip()
    location      = data.get('location', '').strip()
    property_type = data.get('property_type', '').strip()
    price_range   = data.get('price_range', '').strip()

    if not phone:
        return jsonify({'success': False, 'error': 'phone required'}), 400

    errors = []
    
    # 1. Save to Google Sheets (CRITICAL)
    try:
        append_lead(data)
        log.info('[/new-lead] ✓ Sheet1 written successfully')
    except Exception as e:
        log.error(f'[/new-lead] Sheets critical failure: {traceback.format_exc()}')
        return jsonify({
            'success': False, 
            'error': f'Failed to save lead to Database: {str(e)}',
            'hint': 'Check if the spreadsheet is shared with the service account email.'
        }), 500

    # 2. Twilio SMS (Non-critical)
    sms_ok = send_sms(phone,
        f"Hi {name}! Thank you for your inquiry about a {property_type} in {location}. "
        f"Our AI agent will call you within 5 minutes. — ESTAT·IQ"
    )

    # 3. Bland.ai call (Critical logic but continues)
    try:
        bland_resp = fire_bland_call(phone, name, location, property_type, price_range)
        append_calling({'full_name': name, 'phone': phone})
        log.info(f'[/new-lead] ✓ Bland.ai call fired: {bland_resp.get("call_id") or "NO-ID"}')
    except Exception as e:
        log.error(f'[/new-lead] Bland error: {traceback.format_exc()}')
        errors.append(f'Call failed: {str(e)}')

    status_code = 200 if not errors else 500
    
    return jsonify({
        'success': len(errors) == 0,
        'sms_sent': sms_ok,
        'errors': errors,
        'data_saved': True,
        'error': errors[0] if errors else None # Added for easier Flutter parsing
    }), status_code


@app.route('/trigger-call', methods=['POST'])
def trigger_call():
    """Manually re-trigger an AI call (from admin panel)."""
    data = request.get_json(force=True) or {}
    phone = data.get('phone_number', data.get('phone', '')).strip()
    name  = data.get('full_name', '').strip()
    
    if not phone:
        return jsonify({'success': False, 'error': 'phone_number required'}), 400

    # Clean phone for searching
    phone_digits = "".join(filter(str.isdigit, phone))
    
    # Try to find existing lead context
    lead = find_lead_by_phone(phone_digits)
    
    if lead:
        log.info(f'[/trigger-call] Context found for {phone}')
        name = lead.get('Full Name', name)
        loc  = lead.get('Location', 'your preferred area')
        pt   = lead.get('Property Type', 'property')
        bud  = lead.get('Budget', 'your budget')
    else:
        log.info(f'[/trigger-call] No context found for {phone}, using generic prompt')
        loc, pt, bud = 'your preferred area', 'property', 'your budget'

    # Fire call
    try:
        resp = fire_bland_call(phone, name, loc, pt, bud)
        append_calling({'full_name': name, 'phone': phone})
        return jsonify({
            'success': True,
            'call_id': resp.get('call_id'),
            'message': 'Call triggered successfully'
        }), 200
    except Exception as e:
        log.error(f'[/trigger-call] failed: {traceback.format_exc()}')
        return jsonify({
            'success': False,
            'error': f'Call failed: {str(e)}'
        }), 500


@app.route('/book-appointment', methods=['POST'])
def book_appointment():
    """Save a confirmed appointment + send SMS."""
    data = request.get_json(force=True) or {}
    log.info(f'[/book-appointment] {data}')

    name  = data.get('full_name', '').strip()
    phone = data.get('phone', '').strip()
    date  = data.get('appointment_date', '').strip()
    time  = data.get('appointment_time', '').strip()

    if not phone:
        return jsonify({'success': False, 'error': 'phone required'}), 400

    errors = []

    try:
        append_appointment(data)
        log.info('[/book-appointment] ✓ Appointments sheet written')
    except Exception as e:
        errors.append(f'Sheets: {e}')
        log.error(traceback.format_exc())

    send_sms(phone,
        f"Hi {name}! Your site visit is confirmed for {date} at {time} "
        f"in {data.get('location', '')}. See you then! — ESTAT·IQ"
    )

    return jsonify({'success': True, 'errors': errors}), 200


@app.route('/diagnostic', methods=['GET'])
def diagnostic():
    """Run a comprehensive health check on all integrations."""
    results = {
        'sheets': {'status': 'Checking...', 'error': None},
        'twilio': {'status': 'Checking...', 'error': None},
        'bland_ai': {'status': 'Checking...', 'error': None},
        'sheet_naming': {'status': 'Checking...', 'error': None}
    }

    # 1. Test Google Sheets Write
    try:
        gc = get_sheets_client()
        ss = gc.open_by_key(SPREADSHEET_ID)
        ws = ss.worksheet('Sheet1')
        test_row = [datetime.utcnow().isoformat(), 'DIAGNOSTIC TEST', '0000000000', 'N/A', 'N/A', 'N/A', 'diagnostic']
        ws.append_row(test_row, value_input_option='RAW')
        results['sheets']['status'] = 'OK'
    except Exception as e:
        results['sheets']['status'] = 'FAIL'
        results['sheets']['error'] = str(e)

    # 2. Test Sheet Tab Structure
    try:
        ss = gc.open_by_key(SPREADSHEET_ID)
        existing_tabs = [w.title for w in ss.worksheets()]
        missing = [t for t in ['Sheet1', 'calling', 'Appointments'] if t not in existing_tabs]
        if not missing:
            results['sheet_naming']['status'] = 'OK'
        else:
            results['sheet_naming']['status'] = 'MISSING TABS'
            results['sheet_naming']['error'] = f"Missing: {', '.join(missing)}"
    except Exception as e:
        results['sheet_naming']['status'] = 'FAIL'
        results['sheet_naming']['error'] = str(e)

    # 3. Test Twilio (Lightweight ping)
    try:
        twilio = TwilioClient(TWILIO_SID, TWILIO_TOKEN)
        twilio.api.accounts(TWILIO_SID).fetch()
        results['twilio']['status'] = 'OK'
    except Exception as e:
        results['twilio']['status'] = 'FAIL'
        results['twilio']['error'] = str(e)

    # 4. Test Bland.ai (Call list fetch)
    try:
        h = {"authorization": BLAND_API_KEY}
        r = requests.get("https://api.bland.ai/v1/calls", headers=h, params={'limit': 1}, timeout=5)
        if r.status_code == 200:
            results['bland_ai']['status'] = 'OK'
        else:
            results['bland_ai']['status'] = 'ERROR'
            results['bland_ai']['error'] = f"HTTP {r.status_code}: {r.text[:100]}"
    except Exception as e:
        results['bland_ai']['status'] = 'FAIL'
        results['bland_ai']['error'] = str(e)

    return jsonify(results), 200


@app.route('/test-sms', methods=['POST'])
def test_sms_route():
    data = request.get_json(force=True) or {}
    phone = data.get('phone', '').strip()
    if not phone: return jsonify({'success': False, 'error': 'phone required'}), 400
    ok = send_sms(phone, "ESTAT·IQ Diagnostic: Your Twilio integration is working! ✓")
    return jsonify({'success': ok}), 200 if ok else 500

@app.route('/test-call', methods=['POST'])
def test_call_route():
    data = request.get_json(force=True) or {}
    phone = data.get('phone', '').strip()
    if not phone: return jsonify({'success': False, 'error': 'phone required'}), 400
    try:
        resp = fire_bland_call(phone, "Diagnostic User", "Test Loc", "Test Type", "Test Budget")
        return jsonify({'success': True, 'call_id': resp.get('call_id')}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    # Try one-time setup
    ensure_sheet_setup()
    port = int(os.getenv('PORT', 5000))
    log.info(f'Starting ESTAT·IQ backend on port {port}')
    app.run(host='0.0.0.0', port=port, debug=False)
