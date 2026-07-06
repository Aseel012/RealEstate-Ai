"""
Enhanced Real Estate Bot with Automatic Call Triggering
This version includes automated calling within minutes of lead submission
"""

import os
import time
import threading
from datetime import datetime, timedelta
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import google.generativeai as genai
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
from flask import Flask, request, jsonify
import json
import schedule

# Configuration
GEMINI_API_KEY = "AIzaSyCgqw3VqqjkoTDjH36aOfqWHaGlT214DPg"
genai.configure(api_key=GEMINI_API_KEY)

# Google Sheets Configuration
SCOPE = [
    "https://spreadsheets.google.com/feeds",
    "https://www.googleapis.com/auth/drive"
]

# Twilio Configuration - UPDATE THESE
TWILIO_ACCOUNT_SID = os.environ.get('TWILIO_ACCOUNT_SID', 'your_account_sid')
TWILIO_AUTH_TOKEN = os.environ.get('TWILIO_AUTH_TOKEN', 'your_auth_token')
TWILIO_PHONE_NUMBER = os.environ.get('TWILIO_PHONE_NUMBER', 'your_twilio_number')

# Spreadsheet ID - UPDATE THIS
SPREADSHEET_ID = os.environ.get('SPREADSHEET_ID', 'your_spreadsheet_id')

# Flask app
app = Flask(__name__)

# Store active calls
active_calls = {}
call_history = {}


class EnhancedRealEstateBot:
    def __init__(self):
        self.model = genai.GenerativeModel('gemini-pro')
        self.conversation_states = {}
        self.sheet_client = None

    def connect_to_sheets(self, credentials_file=None):
        """Connect to Google Sheets"""
        try:
            if credentials_file and os.path.exists(credentials_file):
                creds = ServiceAccountCredentials.from_json_keyfile_name(
                    credentials_file, SCOPE
                )
            else:
                # Try to use environment variable
                creds_json = os.environ.get('GOOGLE_CREDENTIALS')
                if creds_json:
                    creds_dict = json.loads(creds_json)
                    creds = ServiceAccountCredentials.from_json_keyfile_dict(
                        creds_dict, SCOPE
                    )
                else:
                    raise Exception("No credentials found")

            self.sheet_client = gspread.authorize(creds)
            return self.sheet_client
        except Exception as e:
            print(f"Error connecting to sheets: {e}")
            return None

    def get_lead_by_phone(self, phone_number):
        """Get lead details by phone number"""
        try:
            sheet = self.sheet_client.open_by_key(SPREADSHEET_ID).worksheet("Form Responses")
            all_records = sheet.get_all_records()

            for record in all_records:
                if str(record.get('Phone Number', '')) == str(phone_number):
                    return record

            return None
        except Exception as e:
            print(f"Error getting lead: {e}")
            return None

    def get_uncalled_leads(self):
        """Get leads that haven't been called yet"""
        try:
            sheet = self.sheet_client.open_by_key(SPREADSHEET_ID).worksheet("Form Responses")
            all_records = sheet.get_all_records()

            uncalled_leads = []
            for record in all_records:
                called_status = str(record.get('Called', '')).lower()
                if called_status != 'yes':
                    # Check timestamp - only call if submitted in last 24 hours
                    timestamp_str = record.get('Timestamp', '')
                    if timestamp_str:
                        # Add to queue
                        uncalled_leads.append(record)

            return uncalled_leads
        except Exception as e:
            print(f"Error getting uncalled leads: {e}")
            return []

    def get_properties(self, location, budget_range, property_type):
        """Get matching properties"""
        try:
            sheet = self.sheet_client.open_by_key(SPREADSHEET_ID).worksheet("Properties")
            all_properties = sheet.get_all_records()

            matching = []
            for prop in all_properties:
                if (prop.get('Location', '').lower() == location.lower() and
                        self._matches_budget(prop.get('Price'), budget_range) and
                        prop.get('Property Type', '').lower() == property_type.lower()):
                    matching.append(prop)

            return matching[:3]  # Return top 3 matches
        except Exception as e:
            print(f"Error getting properties: {e}")
            return []

    def _matches_budget(self, price, budget_range):
        """Check if price matches budget range"""
        budget_map = {
            "Under ₹20 Lakhs": (0, 20),
            "₹20 - ₹40 Lakhs": (20, 40),
            "₹40 - ₹60 Lakhs": (40, 60),
            "₹60 - ₹80 Lakhs": (60, 80),
            "₹80 Lakhs - ₹1 Crore": (80, 100),
            "Above ₹1 Crore": (100, 999999),
        }

        if budget_range not in budget_map:
            return False

        try:
            price_str = str(price).replace('₹', '').replace('Lakhs', '').replace('Crore', '').strip()
            price_num = float(price_str)

            if 'Crore' in str(price):
                price_num *= 100

            min_price, max_price = budget_map[budget_range]
            return min_price <= price_num <= max_price
        except:
            return False

    def generate_dynamic_response(self, conversation_history, user_input, lead_info, properties):
        """Generate contextual response using Gemini"""

        prompt = f"""
You are a professional real estate agent on a phone call with {lead_info.get('Full Name', 'the customer')}.

Customer Requirements:
- Location: {lead_info.get('Location')}
- Property Type: {lead_info.get('Property Type')}
- Budget: {lead_info.get('Price Range')}

Available Properties:
{json.dumps(properties, indent=2)}

Conversation so far:
{json.dumps(conversation_history, indent=2)}

Customer just said: "{user_input}"

Generate a natural, conversational response (2-3 sentences maximum) that:
1. Responds appropriately to what they said
2. Keeps the conversation moving forward
3. If presenting properties, highlight ONE key feature
4. If they show interest, ask about scheduling a visit
5. If they're not interested, politely thank them

Be warm, professional, and natural - like a friendly real estate agent.
Response only - no prefixes or labels.
"""

        try:
            response = self.model.generate_content(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"Error generating response: {e}")
            return "I understand. Let me connect you with one of our team members who can assist you further."

    def analyze_final_conversation(self, conversation_history, lead_info):
        """Analyze complete conversation"""

        prompt = f"""
Analyze this complete phone conversation:

Customer: {lead_info.get('Full Name')}
Requirements: {json.dumps(lead_info)}

Full Conversation:
{json.dumps(conversation_history, indent=2)}

Return ONLY valid JSON:
{{
    "interest_level": "High/Medium/Low/Not Interested",
    "properties_discussed": ["names"],
    "meeting_scheduled": "Yes/No",
    "preferred_date": "date or empty",
    "preferred_time": "time or empty",
    "key_concerns": "brief summary",
    "follow_up_action": "what to do next"
}}
"""

        try:
            response = self.model.generate_content(prompt)
            result = response.text.strip()

            # Clean JSON
            if "```json" in result:
                result = result.split("```json")[1].split("```")[0]
            elif "```" in result:
                result = result.split("```")[1].split("```")[0]

            return json.loads(result.strip())
        except Exception as e:
            print(f"Error analyzing: {e}")
            return {
                "interest_level": "Unknown",
                "properties_discussed": [],
                "meeting_scheduled": "No",
                "follow_up_action": "Manual follow-up required"
            }

    def save_feedback(self, lead_info, analysis):
        """Save call feedback to sheet"""
        try:
            sheet = self.sheet_client.open_by_key(SPREADSHEET_ID).worksheet("Feedback")

            row = [
                datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                lead_info.get('Full Name', ''),
                lead_info.get('Phone Number', ''),
                lead_info.get('Location', ''),
                lead_info.get('Property Type', ''),
                lead_info.get('Price Range', ''),
                analysis.get('interest_level', ''),
                ', '.join(analysis.get('properties_discussed', [])),
                analysis.get('meeting_scheduled', ''),
                analysis.get('preferred_date', ''),
                analysis.get('preferred_time', ''),
                analysis.get('key_concerns', ''),
                analysis.get('follow_up_action', '')
            ]

            sheet.append_row(row)
            print(f"Feedback saved for {lead_info.get('Full Name')}")

        except Exception as e:
            print(f"Error saving feedback: {e}")

    def mark_as_called(self, phone_number):
        """Mark lead as called"""
        try:
            sheet = self.sheet_client.open_by_key(SPREADSHEET_ID).worksheet("Form Responses")
            all_records = sheet.get_all_records()

            for idx, record in enumerate(all_records, start=2):
                if str(record.get('Phone Number', '')) == str(phone_number):
                    headers = sheet.row_values(1)

                    if 'Called' in headers:
                        col_idx = headers.index('Called') + 1
                    else:
                        col_idx = len(headers) + 1
                        sheet.update_cell(1, col_idx, 'Called')

                    sheet.update_cell(idx, col_idx, 'Yes')
                    sheet.update_cell(idx, col_idx + 1, datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
                    break

        except Exception as e:
            print(f"Error marking as called: {e}")


# Initialize bot
bot = EnhancedRealEstateBot()


@app.route("/")
def home():
    return jsonify({
        "status": "online",
        "service": "Real Estate AI Calling Bot",
        "version": "2.0"
    })


@app.route("/trigger-call", methods=['POST'])
def trigger_call():
    """Manually trigger a call"""
    data = request.json
    phone_number = data.get('phone_number')

    if not phone_number:
        return jsonify({'error': 'Phone number required'}), 400

    try:
        # Connect to sheets if not connected
        if not bot.sheet_client:
            bot.connect_to_sheets('credentials.json')

        # Get lead info
        lead = bot.get_lead_by_phone(phone_number)
        if not lead:
            return jsonify({'error': 'Lead not found'}), 404

        # Initiate Twilio call
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

        # Add +91 for India
        formatted_number = f"+91{phone_number}"

        call = client.calls.create(
            to=formatted_number,
            from_=TWILIO_PHONE_NUMBER,
            url=f"{request.url_root}voice?phone={phone_number}",
            status_callback=f"{request.url_root}call-status"
        )

        # Store call info
        active_calls[phone_number] = {
            'call_sid': call.sid,
            'lead_info': lead,
            'started_at': datetime.now().isoformat(),
            'conversation': []
        }

        return jsonify({
            'success': True,
            'call_sid': call.sid,
            'message': f'Call initiated to {phone_number}'
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/voice", methods=['POST'])
def voice():
    """Handle incoming call"""
    phone_number = request.values.get('phone', request.values.get('From', '').replace('+91', ''))

    response = VoiceResponse()

    # Get lead info
    if phone_number not in active_calls:
        if not bot.sheet_client:
            bot.connect_to_sheets('credentials.json')

        lead = bot.get_lead_by_phone(phone_number)
        if lead:
            properties = bot.get_properties(
                lead.get('Location', ''),
                lead.get('Price Range', ''),
                lead.get('Property Type', '')
            )

            active_calls[phone_number] = {
                'lead_info': lead,
                'properties': properties,
                'conversation': [],
                'stage': 'greeting'
            }

    # Initial greeting
    call_data = active_calls.get(phone_number, {})
    lead_name = call_data.get('lead_info', {}).get('Full Name', 'there')

    greeting = f"Hello {lead_name}! This is calling from XYZ Real Estate. " \
               f"Thank you for your interest in properties in {call_data.get('lead_info', {}).get('Location', 'your area')}. " \
               f"Am I speaking with {lead_name}?"

    response.say(greeting, voice='Polly.Aditi', language='en-IN')

    gather = Gather(
        input='speech',
        timeout=5,
        action='/handle-speech',
        language='en-IN',
        speech_timeout='auto'
    )
    response.append(gather)

    return str(response)


@app.route("/handle-speech", methods=['POST'])
def handle_speech():
    """Handle user speech responses"""
    phone_number = request.values.get('phone', request.values.get('From', '').replace('+91', ''))
    speech_result = request.values.get('SpeechResult', '').strip()

    response = VoiceResponse()

    if phone_number not in active_calls:
        response.say("Sorry, I lost the context. Please try again.", voice='Polly.Aditi', language='en-IN')
        return str(response)

    call_data = active_calls[phone_number]

    # Store conversation
    call_data['conversation'].append({
        'speaker': 'customer',
        'text': speech_result,
        'timestamp': datetime.now().isoformat()
    })

    # Check for ending signals
    ending_words = ['goodbye', 'bye', 'thank you bye', 'thats all', 'no thanks', 'not interested']
    if any(word in speech_result.lower() for word in ending_words):
        response.say(
            "Thank you for your time! We'll follow up with you soon. Have a great day!",
            voice='Polly.Aditi',
            language='en-IN'
        )

        # Save feedback
        analysis = bot.analyze_final_conversation(
            call_data['conversation'],
            call_data['lead_info']
        )
        bot.save_feedback(call_data['lead_info'], analysis)
        bot.mark_as_called(phone_number)

        # Clean up
        call_history[phone_number] = active_calls.pop(phone_number)

        return str(response)

    # Generate contextual response
    bot_response = bot.generate_dynamic_response(
        call_data['conversation'],
        speech_result,
        call_data['lead_info'],
        call_data.get('properties', [])
    )

    call_data['conversation'].append({
        'speaker': 'agent',
        'text': bot_response,
        'timestamp': datetime.now().isoformat()
    })

    response.say(bot_response, voice='Polly.Aditi', language='en-IN')

    # Continue gathering
    gather = Gather(
        input='speech',
        timeout=5,
        action='/handle-speech',
        language='en-IN',
        speech_timeout='auto'
    )
    response.append(gather)

    return str(response)


@app.route("/call-status", methods=['POST'])
def call_status():
    """Handle call status updates"""
    call_sid = request.values.get('CallSid')
    call_status = request.values.get('CallStatus')

    print(f"Call {call_sid}: {call_status}")

    return '', 200


def check_and_call_leads():
    """Background job to check for new leads and call them"""
    print("Checking for new leads...")

    if not bot.sheet_client:
        bot.connect_to_sheets('credentials.json')

    if not bot.sheet_client:
        print("Failed to connect to sheets")
        return

    uncalled_leads = bot.get_uncalled_leads()
    print(f"Found {len(uncalled_leads)} uncalled leads")

    for lead in uncalled_leads:
        phone = lead.get('Phone Number', '')

        # Skip if already in active calls or recently called
        if phone in active_calls or phone in call_history:
            continue

        print(f"Initiating call to {lead.get('Full Name')} - {phone}")

        try:
            # Trigger call
            client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

            call = client.calls.create(
                to=f"+91{phone}",
                from_=TWILIO_PHONE_NUMBER,
                url=f"{os.environ.get('BASE_URL', 'http://localhost:5000')}/voice?phone={phone}",
                status_callback=f"{os.environ.get('BASE_URL', 'http://localhost:5000')}/call-status"
            )

            print(f"Call initiated: {call.sid}")

            # Wait between calls
            time.sleep(10)

        except Exception as e:
            print(f"Error calling {phone}: {e}")


def run_scheduler():
    """Run background scheduler"""
    schedule.every(5).minutes.do(check_and_call_leads)

    while True:
        schedule.run_pending()
        time.sleep(60)


if __name__ == "__main__":
    # Connect to sheets on startup
    bot.connect_to_sheets('credentials.json')

    # Start background scheduler in a thread
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()

    # Run Flask app
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)