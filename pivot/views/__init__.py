from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.views.generic import TemplateView


class HomeView(TemplateView):
    template_name = 'index.html'


class CourseGPAView(TemplateView):
    template_name = 'course-gpa.html'


class FeedbackView(TemplateView):
    template_name = 'feedback.html'


class MajorGPAView(TemplateView):
    template_name = 'major-gpa.html'


class About(TemplateView):
    template_name = 'about.html'


class PivotTemplateView(TemplateView):
    template_name = 'template.html'


def user_login(request):
    return HttpResponseRedirect(request.GET.get('next', '/major-gpa/'))
