# Copyright 2022 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.db import models


class DataFile(models.Model):
    csv = models.FileField()

    class Meta:
        managed = False
