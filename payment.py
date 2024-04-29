import yookassa
from yookassa import Payment

yookassa.Configuration.account_id = 283923
yookassa.Configuration.secret_key = 'live_rqhdy1qpZpMoQqQeTEzkaMkrmcNY17ZPeFwlWf573ro'

def create(payment_plan, chat_id, user_id):
    payment = Payment.create(
        {
            "amount": {
                "value": payment_plan['price'],
                "currency": "RUB"
            },
            "confirmation": {
                "type": "redirect",
                "return_url": "https://t.me/FreeVpnDownloadBot"
            },
            "capture": True,
            "description": "Оплата VPN на 1 мес.",
            'metadata': {
                'user_id': user_id,
                'chat_id': chat_id,
                'month_count': payment_plan['month_count']
            },
            "receipt": {
                "customer": {
                    "full_name": "Ivanov Ivan Ivanovich",
                    "email": "email@email.ru",
                },
                "items": [
                    {
                        "description": "Оплата VPN на 1 мес.",
                        "quantity": "1",
                        "amount": {
                            "value": payment_plan['price'],
                            "currency": "RUB"
                        },
                        "vat_code": "1",
                        "payment_subject": "commodity",
                        "country_of_origin_code": "RU",
                    },
                ]
            }
        }
    )
    return payment.confirmation.confirmation_url, payment.id


def check(payment_id):
    payment = yookassa.Payment.find_one(payment_id)
    if payment.status == 'succeeded':
        payment_status = payment
    else:
        payment_status = False
    return payment_status, payment.metadata

