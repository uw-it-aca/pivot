from django.db import models


class DataFile(models.Model):
    csv = models.FileField()

    class Meta:
        managed = False
