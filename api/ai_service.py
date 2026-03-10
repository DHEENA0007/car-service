"""
AI Vehicle Issue Detection Service using GROQ API with Llama Vision model.
Analyzes uploaded vehicle images and returns diagnosis.
"""

import json
import base64
import logging
from django.conf import settings
from groq import Groq

logger = logging.getLogger(__name__)


def encode_image_to_base64(image_path):
    """Convert image file to base64 string."""
    with open(image_path, "rb") as image_file:
        return base64.standard_b64encode(image_file.read()).decode("utf-8")


def analyze_vehicle_image(image_path, user_description=""):
    """
    Analyze a vehicle image using GROQ's Llama Vision model.

    Args:
        image_path: Path to the uploaded image file
        user_description: Optional text description from user

    Returns:
        dict with analysis results
    """
    try:
        client = Groq(api_key=settings.GROQ_API_KEY)

        # Encode image to base64
        base64_image = encode_image_to_base64(image_path)

        # Determine image MIME type
        image_path_str = str(image_path).lower()
        if image_path_str.endswith(".png"):
            mime_type = "image/png"
        elif image_path_str.endswith(".webp"):
            mime_type = "image/webp"
        elif image_path_str.endswith(".gif"):
            mime_type = "image/gif"
        else:
            mime_type = "image/jpeg"

        # Build prompt
        prompt = """You are an expert automotive mechanic and vehicle diagnostics specialist.

FIRST, check if this image contains a vehicle (car, truck, motorcycle, bus, van, etc.).

If NO vehicle is detected, respond ONLY with this exact JSON:
{
    "no_vehicle_detected": true,
    "detected_issue": "No Vehicle Detected",
    "confidence_score": 0,
    "problem_explanation": "The uploaded image does not appear to contain a vehicle. Please upload a clear photo of your vehicle showing the issue.",
    "possible_causes": "",
    "urgency_level": "low",
    "recommended_service_type": "",
    "additional_notes": ""
}

If a vehicle IS detected, analyze the issue and respond ONLY with this exact JSON (no extra text, no markdown):
{
    "no_vehicle_detected": false,
    "detected_issue": "Brief name of the detected problem",
    "confidence_score": 85,
    "problem_explanation": "Detailed explanation of what the problem is and why it happens",
    "possible_causes": "List of possible causes separated by semicolons",
    "urgency_level": "low|medium|high|critical",
    "recommended_service_type": "Type of service shop/specialist needed",
    "additional_notes": "Any extra advice for the vehicle owner"
}

Rules for urgency_level:
- "low": Minor cosmetic or non-urgent issue
- "medium": Should be addressed soon but not dangerous
- "high": Needs prompt attention, could worsen
- "critical": Dangerous, needs immediate professional attention"""

        if user_description:
            prompt += f"\n\nThe user also describes the problem as: \"{user_description}\""

        # Call GROQ API with vision model
        chat_completion = client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}",
                            },
                        },
                    ],
                }
            ],
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            temperature=0.3,
            max_completion_tokens=1024,
            top_p=1,
        )

        response_text = chat_completion.choices[0].message.content
        logger.info(f"GROQ raw response: {response_text}")

        # Parse JSON from response
        result = _parse_ai_response(response_text)
        result["raw_response"] = response_text
        return result

    except Exception as e:
        logger.error(f"AI Analysis error: {str(e)}")
        return {
            "detected_issue": "Analysis Error",
            "confidence_score": 0,
            "problem_explanation": f"Unable to analyze image: {str(e)}",
            "possible_causes": "Image quality issues; API connection error; Unsupported image format",
            "urgency_level": "medium",
            "recommended_service_type": "General Auto Service",
            "raw_response": str(e),
            "error": True,
        }


def _parse_ai_response(response_text):
    """Parse the AI response and extract structured data."""
    try:
        # Try direct JSON parse
        result = json.loads(response_text)
        return _validate_result(result)
    except json.JSONDecodeError:
        pass

    # Try to find JSON within the response
    try:
        start = response_text.find("{")
        end = response_text.rfind("}") + 1
        if start != -1 and end > start:
            json_str = response_text[start:end]
            result = json.loads(json_str)
            return _validate_result(result)
    except (json.JSONDecodeError, ValueError):
        pass

    # Fallback: create structured response from text
    return {
        "detected_issue": "Vehicle Issue Detected",
        "confidence_score": 70,
        "problem_explanation": response_text,
        "possible_causes": "Please see the explanation above",
        "urgency_level": "medium",
        "recommended_service_type": "General Auto Service",
    }


def _validate_result(result):
    """Validate and ensure all required fields exist."""
    # If no vehicle detected, return as-is without filling defaults
    if result.get("no_vehicle_detected") is True:
        result.setdefault("detected_issue", "No Vehicle Detected")
        result.setdefault("confidence_score", 0)
        result.setdefault("urgency_level", "low")
        return result

    result.setdefault("no_vehicle_detected", False)

    defaults = {
        "detected_issue": "Unknown Issue",
        "confidence_score": 50,
        "problem_explanation": "No explanation available",
        "possible_causes": "Unknown",
        "urgency_level": "medium",
        "recommended_service_type": "General Auto Service",
    }

    for key, default_value in defaults.items():
        if key not in result or not result[key]:
            result[key] = default_value

    # Ensure confidence score is a number
    try:
        result["confidence_score"] = float(result["confidence_score"])
    except (ValueError, TypeError):
        result["confidence_score"] = 50.0

    # Ensure urgency level is valid
    valid_urgency = ["low", "medium", "high", "critical"]
    if result["urgency_level"] not in valid_urgency:
        result["urgency_level"] = "medium"

    return result


# Mapping of detected issues to Mappls Nearby API search keywords.
# Uses terms that yield the best POI results on Mappls (MapmyIndia) in India.
ISSUE_SERVICE_MAPPING = {
    "flat tire": "tyre puncture shop",
    "tire": "tyre puncture shop",
    "tyre": "tyre puncture shop",
    "wheel": "tyre puncture shop",
    "oil leak": "car service center",
    "oil": "car service center",
    "engine": "car service center",
    "brake": "car service center",
    "headlight": "automobile workshop",
    "light": "automobile workshop",
    "battery": "car battery shop",
    "smoke": "car service center",
    "coolant": "car service center",
    "radiator": "car service center",
    "belt": "automobile workshop",
    "windshield": "automobile workshop",
    "glass": "automobile workshop",
    "dent": "denting painting shop",
    "scratch": "denting painting shop",
    "paint": "denting painting shop",
    "exhaust": "automobile workshop",
    "suspension": "car service center",
    "transmission": "car service center",
    "ac": "car ac repair",
    "air condition": "car ac repair",
}


def get_service_search_keyword(detected_issue):
    """Map detected issue to a Mappls-friendly service center search keyword."""
    if not detected_issue:
        return "car service center"

    issue_lower = detected_issue.lower()
    for keyword, service_type in ISSUE_SERVICE_MAPPING.items():
        if keyword in issue_lower:
            return service_type

    return "car service center"
