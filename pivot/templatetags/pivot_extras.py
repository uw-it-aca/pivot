from django import template
from django.conf import settings
from pivot.utils import get_latest_term, get_quarters_for_file, is_more_recent

register = template.Library()


@register.simple_tag
def year_select_tab(num_qtrs):
    end_term = get_latest_term()

    num_years = int(num_qtrs / 4)
    end_year = end_term[2:]
    start_year = str((int(end_term[2:]) - int(num_years)) % 100)

    qtr = end_term[:2].upper()

    return """
        <a href=".?num_qtrs={0}&end_yr={4}&end_qtr={2}">
            <strong>Last {1} Years</strong> <br>
            <span>
                {2}{3} - {2}{4}
            </span>
        </a>
    """.format(num_qtrs, num_years, qtr, start_year, end_year)


# get settings value
@register.simple_tag
def get_settings_value(name):
    return getattr(settings, name, "")
