from api.firebase_config import db


def get_reminder(user_id, reminder_id):
    doc = (
        db.collection("users")
        .document(user_id)
        .collection("reminders")
        .document(reminder_id)
        .get()
    )

    if doc.exists:
        return doc.to_dict()

    return None


def update_vm_status(user_id, reminder_id, vm_status):

    ref = (
        db.collection("users")
        .document(user_id)
        .collection("reminders")
        .document(reminder_id)
    )

    ref.update({
        "vmStatus": vm_status
    })

    return True