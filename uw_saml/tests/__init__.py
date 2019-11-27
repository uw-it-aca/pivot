import copy

MOCK_SAML_ATTRIBUTES = {
    'urn:oid:0.9.2342.19200300.100.1.1': ['javerage'],
    'urn:oid:1.3.6.1.4.1.5923.1.1.1.1': ['student'],
    'urn:oid:1.3.6.1.4.1.5923.1.1.1.6': ['javerage@washington.edu'],
    'urn:oid:1.3.6.1.4.1.5923.1.1.1.9': ['student@washington.edu'],
    'urn:oid:1.3.6.1.4.1.5923.1.5.1.1': [
        'urn:mace:washington.edu:groups:u_test_group',
        'urn:mace:washington.edu:groups:u_test2_group'],
}


MOCK_SESSION_ATTRIBUTES = {
    'uwnetid': ['javerage'],
    'affiliations': ['student'],
    'eppn': ['javerage@washington.edu'],
    'scopedAffiliations': ['student@washington.edu'],
    'isMemberOf': ['u_test_group', 'u_test2_group'],
}

UW_SAML_PERMISSIONS = {
    'perm1': 'u_test_group',
    'perm2': 'u_test_another_group',
    'perm3': 'u_astratest_myuw_test-support-admin'
}

UW_SAML_MOCK = {
    'NAME_ID': 'mock-nameid',
    'SESSION_INDEX': 'mock-session',
    'SAML_USERS': [
        {
            "username": "test_user",
            "password": "test_password",
            "email": "test_user@uw.edu",
            "MOCK_ATTRIBUTES": {
                'uwnetid': ["test_user"],
                'affiliations': ['student', 'member'],
                'eppn': ['javerage@washington.edu'],
                'scopedAffiliations': [
                    'student@washington.edu',
                    'member@washington.edu'
                ],
                'isMemberOf': [
                    UW_SAML_PERMISSIONS['perm1'],
                    UW_SAML_PERMISSIONS['perm2']
                ],
            }
        },
        {
            "username": "test_user2",
            "password": "test_password2",
            "email": "test_user2@uw.edu",
            "MOCK_ATTRIBUTES": {
                'uwnetid': ["test_user2"],
                'affiliations': ['student', 'member'],
                'eppn': ['javerage@washington.edu'],
                'scopedAffiliations': [
                    'student@washington.edu',
                    'member@washington.edu'
                ],
                'isMemberOf': [
                    UW_SAML_PERMISSIONS['perm1'],
                    UW_SAML_PERMISSIONS['perm2']
                ],
            }
        }
    ]
}

UW_SAML_MOCK_WITH_AUTO_LOGIN = copy.deepcopy(UW_SAML_MOCK)
UW_SAML_MOCK_WITH_AUTO_LOGIN['AUTO_LOGIN_USER'] = \
    UW_SAML_MOCK_WITH_AUTO_LOGIN['SAML_USERS'][1]
