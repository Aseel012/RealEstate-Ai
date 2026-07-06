import os
import json
import logging
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from flask import Flask, request, jsonify, Response
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
import google.generativeai as genai

app = Flask(__name__)

# Configuration
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', 'xxxxxxxxxxxxxxxxxxxxxxxxxx')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', 'xxxxxxxxxxxxxxxxxxxxxxxx')
TWILIO_PHONE_NUMBER = os.getenv('TWILIO_PHONE_NUMBER', '+xxxxxxxxxxxxxx')
SPREADSHEET_ID = os.getenv('SPREADSHEET_ID', '1t-xxxxxxxxxxxxxxxxxxxxxxxxx')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Setup Gemini
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-pro')

# Global conversation state (in-memory for demo purposes)
conversations = {}

def connect_to_sheets(creds_file='credentials.json'):
    scope = ['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']
    creds = ServiceAccountCredentials.from_json_keyfile_name(creds_file, scope)
    client = gspread.authorize(creds)
    return client

def get_properties(client, sheet_id, location, price_range, property_type):
    try:
        sheet = client.open_by_key(sheet_id).worksheet('PROPERTIES')
        all_properties = sheet.get_all_records()
        # Simple filtering logic (can be improved)
        matches = []
        for p in all_properties:
            # Basic fuzzy match or exact match depending on data quality
            if location.lower() in p.get('Location', '').lower():
                matches.append(p)
        return matches
    except Exception as e:
        logger.error(f"Error fetching properties: {e}")
        return []

@app.route("/trigger-call", methods=['POST'])
def trigger_call():
    """Endpoint to trigger automated call"""
    data = request.json
    phone_number = data.get('phone_number')
    
    if not phone_number:
        return jsonify({'error': 'Phone number required'}), 400
    
    try:
        # Get lead info from sheets
        client_sheets = connect_to_sheets()
        spreadsheet = client_sheets.open_by_key(SPREADSHEET_ID)
        leads_sheet = spreadsheet.worksheet('LEADS')
        
        # Find the lead using get_all_values to avoid header errors
        all_values = leads_sheet.get_all_values()
        if not all_values:
             return jsonify({'error': 'Sheet is empty'}), 404
             
        headers = all_values[0]
        data_rows = all_values[1:]
        
        # Try to find 'Phone Number' column, otherwise assume index 2 (Column C)
        try:
            phone_col_idx = headers.index('Phone Number')
        except ValueError:
            phone_col_idx = 2
            
        lead = None
        for row in data_rows:
            # Ensure row has enough columns
            if len(row) > phone_col_idx and str(row[phone_col_idx]) == str(phone_number):
                # Convert list to dict for compatibility
                lead = {}
                for i, val in enumerate(row):
                    if i < len(headers) and headers[i]:
                        lead[headers[i]] = val
                break
        
        if not lead:
            # If not found in sheets, maybe just proceed with basic info or error?
            # For this demo, we'll proceed assuming it's a valid number
            pass
        
        # Initiate call via Twilio
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        # Construct the URL for the call handling
        # Using ngrok or public URL in production
        url_root = request.url_root
        if 'localhost' in url_root or '127.0.0.1' in url_root:
            logger.warning("Running on localhost, Twilio won't be able to reach this unless tunneled.")
        
        webhook_url = f"{url_root}voice?lead_id={phone_number}"
        
        call = client.calls.create(
            to=f"+91{phone_number}" if not phone_number.startswith('+') else phone_number,
            from_=TWILIO_PHONE_NUMBER,
            url=webhook_url
        )
        
        return jsonify({
            'success': True,
            'call_sid': call.sid,
            'message': 'Call initiated'
        }), 200
        
    except Exception as e:
        logger.error(f"Error triggering call: {e}")
        return jsonify({'error': str(e)}), 500

@app.route("/voice", methods=['POST', 'GET'])
def voice():
    """Handle incoming call or triggered call"""
    resp = VoiceResponse()
    args = request.values
    call_sid = args.get('CallSid')
    lead_id = args.get('lead_id')
    
    # Initialize conversation
    if call_sid not in conversations:
        conversations[call_sid] = {
            'history': [],
            'lead_id': lead_id,
            'stage': 'greeting'
        }
        greeting = "Hello! I am calling from Real Estate Bot. I saw your inquiry. Is this a good time to talk?"
        
        conversations[call_sid]['history'].append(f"Bot: {greeting}")
        
        # Optimize Gather for speech
        gather = Gather(input='speech', action='/voice/process', language='en-IN', speechTimeout='auto')
        gather.say(greeting)
        resp.append(gather)
        
        # If no speech, redirect to process (will handle silence)
        resp.redirect('/voice/process')
    else:
        resp.redirect('/voice/process')
        
    return Response(str(resp), mimetype='text/xml')

@app.route("/voice/process", methods=['POST'])
def process_voice():
    """Process speech input and generate response"""
    resp = VoiceResponse()
    args = request.values
    call_sid = args.get('CallSid')
    user_speech = args.get('SpeechResult')
    
    logger.info(f"Received Speech: {user_speech}")
    
    if not call_sid or call_sid not in conversations:
        resp.say("I'm sorry, I lost our connection. Goodbye.")
        return Response(str(resp), mimetype='text/xml')
    
    conversation = conversations[call_sid]
    
    # Handle silence/no input
    if not user_speech:
        if len(conversation['history']) > 20: # Safety break
            resp.say("I am having trouble hearing you. I will call you back later. Goodbye.")
            return Response(str(resp), mimetype='text/xml')
            
        gather = Gather(input='speech', action='/voice/process', language='en-IN', speechTimeout='auto', speechModel='phone_call')
        gather.say("I didn't catch that. could you please repeat?")
        resp.append(gather)
        return Response(str(resp), mimetype='text/xml')

    conversation['history'].append(f"User: {user_speech}")
    
    # Simple logic using Gemini to generate response
    try:
        # Construct prompt
        history_text = "\n".join(conversation['history'])
        prompt = f"""
        You are a helpful real estate agent assistant named "PropBot". You are talking to a potential client on the phone.
        Your goal is to qualify the lead by asking about:
        1. Their Budget
        2. Preferred Location
        3. Property Type (Apartment, Villa, etc.)
        
        Current conversation history:
        {history_text}
        
        User just said: "{user_speech}"
        
        Instructions:
        - Provide a natural, friendly spoken response.
        - ALWAYS ask a relevant follow-up question to keep the conversation going.
        - Keep it short (max 2-3 sentences).
        - Do not use detailed lists or special characters like * or -.
        """
        
        response = model.generate_content(prompt)
        bot_reply = response.text.strip().replace('*', '')
        
        logger.info(f"Bot Reply: {bot_reply}")
        conversation['history'].append(f"Bot: {bot_reply}")
        
        gather = Gather(input='speech', action='/voice/process', language='en-IN', speechTimeout='auto', speechModel='phone_call')
        gather.say(bot_reply)
        resp.append(gather)
        
    except Exception as e:
        logger.error(f"Error in AI generation: {e}")
        # Recover from error by asking again instead of hanging up
        gather = Gather(input='speech', action='/voice/process', language='en-IN', speechTimeout='auto', speechModel='phone_call')
        gather.say("I'm sorry, I missed that. Could you say it again?")
        resp.append(gather)
    
    return Response(str(resp), mimetype='text/xml')

if __name__ == "__main__":
    app.run(debug=True, port=int(os.getenv('PORT', 5000)))
