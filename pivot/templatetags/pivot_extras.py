from django import template
from uw_sws.term import get_term_before, get_previous_term

register = template.Library()


@register.simple_tag
def range_to_qtrs(num_qtrs):
    end_term = get_term_before(get_previous_term())

    end_year = end_term.year % 100
    start_year = (int(end_term.year) - int(num_qtrs / 4)) % 100

    qtr = end_term.quarter[:2]

    return str(start_year) + qtr + " - " + str(end_year) + qtr
