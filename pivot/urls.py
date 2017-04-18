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

urlpatterns = [
    # Home
    url(r'^$', RedirectView.as_view(url='/major-gpa')),
    url(r'^course-gpa$', CourseGPAView.as_view(), name='coursegpa'),
    url(r'^major-gpa$', MajorGPAView.as_view(), name='majorgpa'),
    url(r'^feedback$', FeedbackView.as_view(), name='feedback'),
    url(r'^resources$', Resources.as_view(), name='resources'),
    url(r'^template$', PivotTemplateView.as_view(), name='pivottemplate'),
    url(r'^api/v1/major_course$', MajorCourse.as_view(), name='majorcourse'),
    url(r'^api/v1/data_map', DataMap.as_view(), name='datamap'),
    url(r'^api/v1/status_lookup', StatusLookup.as_view(), name='statuslookup'),
    url(r'^api/v1/student_data', StudentData.as_view(), name='studentdata'),
    url(r'^$', HomeView.as_view(), name='home'),

]
