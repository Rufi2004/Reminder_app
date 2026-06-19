def get_voice_message(
    title,
    vm_status="not yet started",
    full_count=0,
    current_count=0,
    balance_count=0,
    completed_days=0
):

    vm_status = str(vm_status).lower().strip()

    if vm_status == "not yet started":
        return (
            "1A",
            f"Today, you haven't started the task {title} yet. "
            f"Please begin it as soon as possible."
        )

    elif vm_status == "not started urgent":
        return (
            "1B",
            f"It's important that we start the task {title} immediately. "
            f"You still have {balance_count} counts remaining and time is running short."
        )

    elif vm_status == "in progress":
        return (
            "2A",
            f"The task {title} is currently in progress. "
            f"{current_count} counts have been completed and "
            f"{balance_count} counts are pending."
        )

    elif vm_status == "slow progress":
        return (
            "2B",
            f"The task {title} is progressing steadily. "
            f"{current_count} counts completed out of "
            f"{full_count} total counts."
        )

    elif vm_status == "near completion":
        return (
            "2C",
            f"The task {title} is almost completed. "
            f"Only {balance_count} counts remain."
        )

    elif vm_status == "achievement" or completed_days >= 3:
        return (
            "3B",
            f"Congratulations. You have successfully completed "
            f"{title} for three consecutive days."
        )

    elif vm_status == "completed":
        return (
            "3A",
            f"The task {title} has been completed successfully."
        )

    return (
        "DEFAULT",
        f"Reminder for {title}"
    )