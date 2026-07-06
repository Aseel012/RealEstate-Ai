"""
Real Estate AI Calling Bot
Integrates with Google Sheets, Gemini AI, and calling service
"""

import os
import time
from datetime import datetime
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import google.generativeai as genai
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Gather
from flask import Flask, request
import json

# Configuration
GEMINI_API_KEY = "AIzaSyCgqw3VqqjkoTDjH36aOfqWHaGlT214DPg"
genai.configure(api_key=GEMINI_API_KEY)

# Google Sheets Configuration
SCOPE = [
    "https://spreadsheets.google.com/feeds",
    "https://www.googleapis.com/auth/drive"
]

# Twilio Configuration (You'll need to sign up for Twilio)
# TWILIO_ACCOUNT_SID = 'your_account_sid'
# TWILIO_AUTH_TOKEN = 'your_auth_token'
# TWILIO_PHONE_NUMBER = 'your_twilio_number'

class RealEstateBot:
    def __init__(self):
        self.model = genai.GenerativeModel('gemini-pro')
        self.conversation_history = {}

    def connect_to_sheets(self, credentials_file):
        """Connect to Google Sheets"""
        try:
            creds = ServiceAccountCredentials.from_json_keyfile_name(
                credentials_file, SCOPE
            )
            client = gspread.authorize(creds)
            return client
        except Exception as e:
            print(f"Error connecting to sheets: {e}")
            return None

    def get_new_leads(self, sheet_client, spreadsheet_id, sheet_name="Form Responses"):
        """Get new leads from Google Sheets"""
        try:
            sheet = sheet_client.open_by_key(spreadsheet_id).worksheet(sheet_name)
            all_records = sheet.get_all_records()

            # Filter leads that haven't been called yet
            new_leads = [record for record in all_records
                        if record.get('Called', '').lower() != 'yes']

            return new_leads
        except Exception as e:
            print(f"Error getting leads: {e}")
            return []

    def get_properties(self, sheet_client, spreadsheet_id,
                      location, budget_range, property_type):
        """Get matching properties from properties sheet"""
        try:
            sheet = sheet_client.open_by_key(spreadsheet_id).worksheet("Properties")
            all_properties = sheet.get_all_records()

            # Filter properties based on criteria
            matching_properties = []
            for prop in all_properties:
                if (prop.get('Location', '').lower() == location.lower() and
                    self._is_in_budget_range(prop.get('Price'), budget_range) and
                    prop.get('Property Type', '').lower() == property_type.lower()):
                    matching_properties.append(prop)

            return matching_properties
        except Exception as e:
            print(f"Error getting properties: {e}")
            return []

    def _is_in_budget_range(self, price, budget_range):
        """Check if price is in budget range"""
        budget_map = {
            "Under ₹20 Lakhs": (0, 20),
            "₹20 - ₹40 Lakhs": (20, 40),
            "₹40 - ₹60 Lakhs": (40, 60),
            "₹60 - ₹80 Lakhs": (60, 80),
            "₹80 Lakhs - ₹1 Crore": (80, 100),
            "Above ₹1 Crore": (100, float('inf'))
        }

        if budget_range not in budget_map:
            return False

        min_price, max_price = budget_map[budget_range]

        # Convert price string to number (assuming format like "₹45 Lakhs")
        try:
            price_num = float(price.replace('₹', '').replace('Lakhs', '').replace('Crore', '').strip())
            if 'Crore' in price:
                price_num *= 100
            return min_price <= price_num <= max_price
        except:
            return False

    def generate_conversation_script(self, lead_info, properties):
        """Generate personalized conversation script using Gemini"""

        prompt = f"""
You are a professional real estate agent making a call to a potential customer.
Generate a natural, conversational script in a friendly Indian style.

Customer Details:
- Name: {lead_info.get('Full Name', 'Sir/Madam')}
- Location Interest: {lead_info.get('Location', 'Not specified')}
- Property Type: {lead_info.get('Property Type', 'Not specified')}
- Budget: {lead_info.get('Price Range', 'Not specified')}

Available Properties:
{json.dumps(properties, indent=2)}

Create a conversation flow that:
1. Greets the customer warmly
2. Confirms their requirements
3. Presents 2-3 best matching properties with enthusiasm
4. Highlights key features of each property
5. Asks if they're interested in scheduling a site visit
6. If yes, asks for their preferred date and time
7. Thanks them and confirms next steps

Keep it natural, not too salesy, and build rapport.
Generate the complete script with agent's lines only.
"""

        try:
            response = self.model.generate_content(prompt)
            return response.text
        except Exception as e:
            print(f"Error generating script: {e}")
            return None

    def analyze_conversation(self, conversation_text, lead_info):
        """Analyze conversation to extract key information"""

        prompt = f"""
Analyze this conversation between a real estate agent and customer:

{conversation_text}

Customer Details: {json.dumps(lead_info)}

Extract and return ONLY a JSON object with:
{{
    "interest_level": "High/Medium/Low/Not Interested",
    "properties_interested": ["property names"],
    "meeting_scheduled": "Yes/No",
    "preferred_date": "date if mentioned",
    "preferred_time": "time if mentioned",
    "additional_notes": "any important points",
    "follow_up_required": "Yes/No"
}}
"""

        try:
            response = self.model.generate_content(prompt)
            result = response.text.strip()

            # Extract JSON from response
            if "```json" in result:
                result = result.split("```json")[1].split("```")[0].strip()
            elif "```" in result:
                result = result.split("```")[1].split("```")[0].strip()

            return json.loads(result)
        except Exception as e:
            print(f"Error analyzing conversation: {e}")
            return {
                "interest_level": "Unknown",
                "properties_interested": [],
                "meeting_scheduled": "No",
                "follow_up_required": "Yes"
            }

    def update_feedback_sheet(self, sheet_client, spreadsheet_id,
                             lead_info, analysis_result):
        """Update feedback sheet with call results"""
        try:
            sheet = sheet_client.open_by_key(spreadsheet_id).worksheet("Feedback")

            row_data = [
                datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                lead_info.get('Full Name', ''),
                lead_info.get('Phone Number', ''),
                lead_info.get('Location', ''),
                lead_info.get('Property Type', ''),
                lead_info.get('Price Range', ''),
                analysis_result.get('interest_level', ''),
                ', '.join(analysis_result.get('properties_interested', [])),
                analysis_result.get('meeting_scheduled', ''),
                analysis_result.get('preferred_date', ''),
                analysis_result.get('preferred_time', ''),
                analysis_result.get('additional_notes', ''),
                analysis_result.get('follow_up_required', '')
            ]

            sheet.append_row(row_data)
            print(f"Feedback updated for {lead_info.get('Full Name')}")

        except Exception as e:
            print(f"Error updating feedback: {e}")

    def mark_lead_as_called(self, sheet_client, spreadsheet_id,
                           phone_number, sheet_name="Form Responses"):
        """Mark lead as called in the main sheet"""
        try:
            sheet = sheet_client.open_by_key(spreadsheet_id).worksheet(sheet_name)
            all_records = sheet.get_all_records()

            for idx, record in enumerate(all_records, start=2):
                if record.get('Phone Number') == phone_number:
                    # Find the 'Called' column
                    headers = sheet.row_values(1)
                    if 'Called' not in headers:
                        # Add 'Called' column if it doesn't exist
                        sheet.update_cell(1, len(headers) + 1, 'Called')
                        col_idx = len(headers) + 1
                    else:
                        col_idx = headers.index('Called') + 1

                    sheet.update_cell(idx, col_idx, 'Yes')
                    break

        except Exception as e:
            print(f"Error marking lead as called: {e}")


# Flask app for handling Twilio webhooks
app = Flask(__name__)
bot = RealEstateBot()

@app.route("/voice", methods=['GET', 'POST'])
def voice():
    """Respond to incoming phone calls with voice bot"""
    response = VoiceResponse()

    # Get user phone number
    caller = request.values.get('From', 'Unknown')

    # Initialize conversation
    if caller not in bot.conversation_history:
        bot.conversation_history[caller] = []

    # First greeting
    response.say(
        "Hello! This is calling from XYZ Real Estate. "
        "Thank you for showing interest in our properties. "
        "Am I speaking with the right person?",
        voice='Polly.Aditi',
        language='en-IN'
    )

    gather = Gather(input='speech', timeout=3, action='/handle-response')
    response.append(gather)

    return str(response)

@app.route("/handle-response", methods=['POST'])
def handle_response():
    """Handle user speech responses"""
    response = VoiceResponse()

    speech_result = request.values.get('SpeechResult', '')
    caller = request.values.get('From', 'Unknown')

    # Store conversation
    bot.conversation_history[caller].append({
        'timestamp': datetime.now().isoformat(),
        'user_response': speech_result
    })

    # Use Gemini to generate next response
    conversation_context = bot.conversation_history[caller]

    # Generate appropriate response using Gemini
    prompt = f"""
Based on this conversation history: {json.dumps(conversation_context)}
User just said: "{speech_result}"

Generate a natural, brief response (max 2-3 sentences) that:
- Acknowledges what they said
- Moves the conversation forward
- Either presents property details, confirms requirements, or schedules meeting

Keep it conversational and natural.
"""

    try:
        gemini_response = bot.model.generate_content(prompt)
        next_message = gemini_response.text
    except:
        next_message = "I understand. Let me help you with that."

    response.say(next_message, voice='Polly.Aditi', language='en-IN')

    # Continue gathering responses
    gather = Gather(input='speech', timeout=3, action='/handle-response')
    response.append(gather)

    return str(response)


def process_new_leads():
    """Main function to process new leads automatically"""

    # Initialize bot
    bot = RealEstateBot()

    # Connect to Google Sheets
    sheet_client = bot.connect_to_sheets('credentials.json')
    if not sheet_client:
        print("Failed to connect to Google Sheets")
        return

    # Your spreadsheet ID (from the URL)
    SPREADSHEET_ID = "your_spreadsheet_id_here"

    # Get new leads
    new_leads = bot.get_new_leads(sheet_client, SPREADSHEET_ID)

    print(f"Found {len(new_leads)} new leads")

    for lead in new_leads:
        print(f"\nProcessing lead: {lead.get('Full Name')}")

        # Get matching properties
        properties = bot.get_properties(
            sheet_client,
            SPREADSHEET_ID,
            lead.get('Location', ''),
            lead.get('Price Range', ''),
            lead.get('Property Type', '')
        )

        print(f"Found {len(properties)} matching properties")

        # Generate conversation script
        script = bot.generate_conversation_script(lead, properties)

        if script:
            print("\nGenerated Script:")
            print(script)

            # Here you would initiate the actual phone call
            # For now, we'll simulate the conversation

            # Simulate conversation (in real implementation, this would be voice)
            simulated_response = """
            Customer: Yes, I'm interested in the properties you mentioned.
            The 3BHK in Nanded sounds good. I'd like to visit it.
            I'm free this Saturday around 11 AM.
            """

            # Analyze conversation
            analysis = bot.analyze_conversation(
                f"Agent: {script}\nCustomer: {simulated_response}",
                lead
            )

            print("\nConversation Analysis:")
            print(json.dumps(analysis, indent=2))

            # Update feedback sheet
            bot.update_feedback_sheet(
                sheet_client,
                SPREADSHEET_ID,
                lead,
                analysis
            )

            # Mark lead as called
            bot.mark_lead_as_called(
                sheet_client,
                SPREADSHEET_ID,
                lead.get('Phone Number', '')
            )

            print(f"Completed processing for {lead.get('Full Name')}")

        # Wait before processing next lead
        time.sleep(2)


if __name__ == "__main__":
    # For development: run Flask app
    # app.run(debug=True, port=5000)

    # For production: run lead processing
    process_new_leads()