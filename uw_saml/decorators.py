from django.contrib.auth.decorators import login_required
from django.shortcuts import render
from uw_saml.utils import is_member_of_group


def group_required(group_id):
    """
    A decorator for views that checks whether the user is a member of the group
    identified by the passed group_id. Calls login_required if the user is not
    authenticated.
    """
    def decorator(view_func):
        def wrapper(request, *args, **kwargs):
            if is_member_of_group(request, group_id):
                return view_func(request, *args, **kwargs)

            return render(request, 'uw_saml/access_denied.html', status=401)

        return login_required(function=wrapper)

    return decorator
