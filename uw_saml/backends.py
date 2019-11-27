from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from django.core.exceptions import ImproperlyConfigured

UserModel = get_user_model()


class SamlMockModelBackend(ModelBackend):
    """
    Custom ModelBacked to provide onelogin SAML like behaviour
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        mock_config = getattr(settings, 'UW_SAML_MOCK', False)
        if mock_config:
            for user in mock_config['SAML_USERS']:
                if user['username'] == username:
                    try:
                        UserModel.objects.get(
                            username=user["username"]
                        )
                    except UserModel.DoesNotExist:
                        new_user = UserModel.objects.create_user(
                            user["username"],
                            user['email'],
                            user["password"]
                        )
                    request.session['samlUserdata'] = user['MOCK_ATTRIBUTES']
                    request.session['samlNameId'] = mock_config['NAME_ID']
                    request.session['samlSessionIndex'] = "{}-{}".format(
                        mock_config['SESSION_INDEX'],
                        username
                    )
        else:
            raise ImproperlyConfigured('UW_SAML_MOCK not found in settings')

        return super().authenticate(request, username, password, **kwargs)
