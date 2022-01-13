# Copyright 2022 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.urls import include, re_path
from django.views.generic.base import RedirectView
import uw_saml

from pivot.views import (
    HomeView,
    PivotTemplateView,
    CourseGPAView,
    MajorGPAView,
    FeedbackView,
    About,
)
from pivot.views.data_api import (
    MajorCourse,
    DataMap,
    StatusLookup,
    StudentData
)


from django.contrib.auth.decorators import login_required

urlpatterns = [
    re_path(r'^$', login_required(RedirectView.as_view(url='/major-gpa/'))),
    re_path(r'^course-gpa/$', login_required(CourseGPAView.as_view()),
            name='coursegpa'),
    re_path(r'^major-gpa/$', login_required(MajorGPAView.as_view()),
            name='majorgpa'),
    re_path(r'^feedback/$', login_required(FeedbackView.as_view()),
            name='feedback'),
    re_path(r'^about/$', login_required(About.as_view()), name='about'),
    re_path(r'^template/$', login_required(PivotTemplateView.as_view()),
            name='pivottemplate'),
    re_path(r'^api/v1/major_course/$', login_required(MajorCourse.as_view()),
            name='majorcourse'),
    re_path(r'^api/v1/data_map/', login_required(DataMap.as_view()),
            name='datamap'),
    re_path(r'^api/v1/status_lookup/', login_required(StatusLookup.as_view()),
            name='statuslookup'),
    re_path(r'^api/v1/student_data/', login_required(StudentData.as_view()),
            name='studentdata'),

]
