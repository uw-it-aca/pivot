from django.conf import settings


def support_email(request):
    return {'support_email': getattr(settings, 'SUPPORT_EMAIL', '')}


def google_analytics(request):
    ga_key = getattr(settings, 'GOOGLE_ANALYTICS_KEY', False)
    return {
        'GOOGLE_ANALYTICS_KEY': ga_key,
        'google_analytics': ga_key
    }
