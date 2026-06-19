import os
import json
from django.http import JsonResponse, FileResponse
from django.views.decorators.csrf import csrf_exempt

from api.services.firebase_service import get_reminder, update_vm_status
from api.services.message_service import get_voice_message
from api.services.tts_service import create_audio


AUDIO_FOLDER = "temp_audio"
os.makedirs(AUDIO_FOLDER, exist_ok=True)


# ---------------- HOME ----------------
def home(request):
    return JsonResponse({
        "success": True,
        "message": "Reminder API Running"
    })


# ---------------- SYNC VM STATUS ----------------
@csrf_exempt
def sync_vm_status(request):

    if request.method != "POST":
        return JsonResponse({"success": False, "message": "POST only"}, status=405)

    try:
        data = json.loads(request.body.decode("utf-8"))

        user_id = data.get("user_id")
        reminder_id = data.get("reminder_id")
        vm_status = data.get("vmStatus")

        if not user_id or not reminder_id:
            return JsonResponse({
                "success": False,
                "message": "Missing user_id or reminder_id"
            }, status=400)

        # 🔥 THIS IS THE REAL DATABASE UPDATE
        update_vm_status(user_id, reminder_id, vm_status)

        return JsonResponse({
            "success": True,
            "message": "VM status updated in Firebase",
            "vmStatus": vm_status
        })

    except Exception as e:
        return JsonResponse({
            "success": False,
            "error": str(e)
        }, status=500)


# ---------------- GENERATE AUDIO ----------------
def generate_audio(request, user_id, reminder_id):

    reminder = get_reminder(user_id, reminder_id)

    if not reminder:
        return JsonResponse({"success": False, "error": "Reminder not found"}, status=404)

    notification_mode = reminder.get("notificationMode", "voice")

    if notification_mode == "ringtone":
        return JsonResponse({
            "success": True,
            "mode": "ringtone",
            "ringtone": reminder.get("notificationSound", "alarm"),
        })

    title = reminder.get("title", "Reminder")
    vm_status = reminder.get("vmStatus", "not yet started")

    full_count = reminder.get("fullCount", 0)
    current_count = reminder.get("currentCount", 0)
    balance_count = reminder.get("balanceCount", 0)
    completed_days = reminder.get("completedDays", 0)

    template_code, speech_text = get_voice_message(
        title,
        vm_status,
        full_count,
        current_count,
        balance_count,
        completed_days
    )

    filename = f"{reminder_id}.mp3"
    filepath = os.path.join(AUDIO_FOLDER, filename)

    create_audio(speech_text, filepath)

    audio_url = request.build_absolute_uri(f"/audio/{filename}")

    return JsonResponse({
        "success": True,
        "mode": "voice",
        "template": template_code,
        "vmStatus": vm_status,
        "title": title,
        "fullCount": full_count,
        "currentCount": current_count,
        "balanceCount": balance_count,
        "message": speech_text,
        "audioUrl": audio_url,
    })


# ---------------- SERVE AUDIO ----------------
def get_audio(request, filename):
    filepath = os.path.join(AUDIO_FOLDER, filename)

    if not os.path.exists(filepath):
        return JsonResponse({"success": False, "error": "File not found"}, status=404)

    return FileResponse(open(filepath, "rb"), content_type="audio/mpeg")