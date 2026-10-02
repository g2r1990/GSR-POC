import logging

logger = logging.getLogger(__name__)


def send_new_order_notification(fcm_token: str, short_id: str, total: float) -> None:
    if not fcm_token:
        return
    try:
        from firebase_admin import messaging
        message = messaging.Message(
            notification=messaging.Notification(
                title="New Order! 🔔",
                body=f"Order #{short_id} — ₹{total:.0f}. Tap to view.",
            ),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(sound="default"),
            ),
            token=fcm_token,
        )
        messaging.send(message)
        logger.info("FCM sent for order %s", short_id)
    except Exception as e:
        logger.warning("FCM send failed: %s", e)
