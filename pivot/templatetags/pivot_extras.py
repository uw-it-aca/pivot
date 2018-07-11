from django import template
from uw_sws import term

register = template.Library()


@register.simple_tag
def range_to_qtrs(num_qtrs):
    previous_term = term.get_previous_term()

    end_year = previous_term.year % 100
    start_year = (int(previous_term.year) - int(num_qtrs / 4)) % 100

    qtr = previous_term.quarter[:2]

    return str(start_year) + qtr + " - " + str(end_year) + qtr
