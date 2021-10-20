# Copyright 2021 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.conf import settings
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.utils.decorators import method_decorator
from django.views.generic import TemplateView

from uw_saml.decorators import group_required

PIVOT_ACCESS_GROUP = settings.PIVOT_AUTHZ_GROUPS['access']


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class HomeView(TemplateView):
    template_name = 'index.html'


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class CourseGPAView(TemplateView):
    template_name = 'course-gpa.html'


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class FeedbackView(TemplateView):
    template_name = 'feedback.html'


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class MajorGPAView(TemplateView):
    template_name = 'major-gpa.html'


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class About(TemplateView):
    template_name = 'about.html'


@method_decorator(group_required(PIVOT_ACCESS_GROUP), name='dispatch')
class PivotTemplateView(TemplateView):
    template_name = 'template.html'
