from django.conf.urls import include, url
from pivot.views import HomeView, PivotTemplateView, CourseGPAView, MajorGPAView, FeedbackView, Resources

urlpatterns = [
    url(r'^$', MajorGPAView.as_view(), name='majorgpa'),
    url(r'^course-gpa$', CourseGPAView.as_view(), name='coursegpa'),
    url(r'^major-gpa$', MajorGPAView.as_view(), name='majorgpa'),
    url(r'^feedback$', FeedbackView.as_view(), name='feedback'),
    url(r'^resources$', Resources.as_view(), name='resources'),
    url(r'^template$', PivotTemplateView.as_view(), name='pivottemplate'),
    url(r'^$', HomeView.as_view(), name='home'),

]
