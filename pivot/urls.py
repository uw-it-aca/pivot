from django.conf.urls import include, url
from django.views.generic.base import RedirectView
from pivot.views import (
    HomeView,
    PivotTemplateView,
    CourseGPAView,
    MajorGPAView,
    FeedbackView,
    Resources
)
from pivot.views.data_api import (
    MajorCourse,
    DataMap,
    StatusLookup,
    StudentData
)
# Auth view
from django.contrib.auth import views as auth_views
from django.contrib.auth.decorators import login_required


urlpatterns = [
    # Authentication pages
    url(r'^login/$', auth_views.login, {'template_name': 'login.html'},\
        name='login'),
    url(r'^logout/$', auth_views.logout, {'next_page': '/login'},\
        name='logout'),
    # Home
    url(r'^$', RedirectView.as_view(url='/major-gpa')),
    # All links are login protected
    url(r'^course-gpa$', login_required(CourseGPAView.as_view()),\
        name='coursegpa'),
    url(r'^major-gpa$', login_required(MajorGPAView.as_view()),\
        name='majorgpa'),
    url(r'^feedback$', login_required(FeedbackView.as_view()),\
        name='feedback'),
    url(r'^resources$', login_required(Resources.as_view()),\
        name='resources'),
    url(r'^template$', login_required(PivotTemplateView.as_view()),\
        name='pivottemplate'),
    url(r'^api/v1/major_course$', login_required(MajorCourse.as_view()),\
        name='majorcourse'),
    url(r'^api/v1/data_map', login_required(DataMap.as_view()),\
        name='datamap'),
    url(r'^api/v1/status_lookup', login_required(StatusLookup.as_view()),\
        name='statuslookup'),
    url(r'^api/v1/student_data', login_required(StudentData.as_view()),\
        name='studentdata'),

]
