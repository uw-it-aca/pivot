from django.http import HttpResponseRedirect


def user_login(request):
    return HttpResponseRedirect(request.GET.get('next', '/'))
