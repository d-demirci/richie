# Generated by Django 2.2.13 on 2020-06-12 14:14

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("courses", "0016_auto_20200417_1237"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Enrollment",
            fields=[
                (
                    "id",
                    models.AutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(auto_now_add=True, verbose_name="created at"),
                ),
                (
                    "course_run",
                    models.ForeignKey(
                        help_text="course run the user enrolled in",
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="enrolled_users",
                        related_query_name="enrolled_user",
                        to="courses.CourseRun",
                        verbose_name="course run",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        help_text="user whose enrollment is represented",
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="enrollments",
                        related_query_name="enrollment",
                        to=settings.AUTH_USER_MODEL,
                        verbose_name="user",
                    ),
                ),
            ],
            options={
                "verbose_name": "enrollment",
                "db_table": "richie_enrollment",
                "unique_together": {("user", "course_run")},
            },
        ),
    ]