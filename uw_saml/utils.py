from django.conf import settings


def get_attribute(request, name):
    """
    Return the SAML attribute stored in session.samlUserdata.
    """
    value = request.session.get('samlUserdata', {}).get(name)

    if value is not None:
        if name not in ['affiliations', 'scopedAffiliations', 'isMemberOf']:
            return value[0] if len(value) else None

    return value


def get_user(request):
    """
    Return the user login stored in session.samlUserdata, identified in
    settings by either 'uwnetid' (default) or 'eppn'.
    """
    user_attr = getattr(settings, 'SAML_USER_ATTRIBUTE', 'uwnetid')
    return get_attribute(request, user_attr)


def is_member_of_group(request, group_id):
    """
    Utility function that checks whether the user is a member of the group
    identified by the passed group_id.
    """
    groups = get_attribute(request, 'isMemberOf') or []
    return group_id in groups
