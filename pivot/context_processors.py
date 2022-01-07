# Copyright 2021 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.conf import settings


def support_email(request):
    return {'support_email': getattr(settings, 'SUPPORT_EMAIL', '')}


def google_analytics(request):
    ga_key = getattr(settings, 'GOOGLE_ANALYTICS_KEY', False)
    return {
        'GOOGLE_ANALYTICS_KEY': ga_key,
        'google_analytics': ga_key
    }

def show_alert(request):
    return {'show_alert': settings.SHOW_ALERT}