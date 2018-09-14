from django import template
from uw_sws.term import get_term_before, get_previous_term

register = template.Library()


@register.simple_tag
def year_select_tab(num_qtrs):
    end_term = get_term_before(get_previous_term())

    num_years = int(num_qtrs / 4)
    end_year = str(end_term.year % 100)
    start_year = str((int(end_term.year) - int(num_years)) % 100)

    qtr = end_term.quarter[:2]

    return """
        <a href=".?num_qtrs={0}&end_yr={4}&end_qtr={2}">
            <strong>Last {1} Years</strong> <br>
            <span>
                {2}{3} - {2}{4}
            </span>
        </a>
    """.format(num_qtrs, num_years, qtr, start_year, end_year)
