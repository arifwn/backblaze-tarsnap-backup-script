#!/usr/bin/env python

import datetime
import json
import sys


def parse_date(file_path):
    path_split = file_path.split('/')
    date = datetime.datetime.strptime(path_split[0], '%Y-%m-%d')
    return date


def deletion_filter(file_list, daily_retain_num=7, weekly_retain_num=8, monthly_retain_num=12):
    deletion_file_list = []

    # today + daily_retain_num days
    daily_cutoff_date = datetime.datetime.now() + datetime.timedelta(days=-daily_retain_num)
    # print 'daily_cutoff_date', daily_cutoff_date

    # today + weekly_retain_num weeks
    weekly_cutoff_date = datetime.datetime.now() + datetime.timedelta(weeks=-weekly_retain_num)
    # print 'weekly_cutoff_date', weekly_cutoff_date

    # today + monthly_retain_num months
    monthly_cutoff_date = datetime.datetime.now() + datetime.timedelta(days=-monthly_retain_num*30)
    # print 'monthly_cutoff_date', monthly_cutoff_date

    for file_item in file_list:
        date = parse_date(file_item['fileName'])

        if date > daily_cutoff_date:
            continue

        if (((date.day % 7) - 1) == 0) and date > weekly_cutoff_date:
            continue

        if (date.day == 1) and date > monthly_cutoff_date:
            continue

        deletion_file_list.append(file_item)

    return deletion_file_list


if __name__ == '__main__':
    source_file = sys.argv[1]
    json_data = None

    with open(source_file) as f:
        json_data = f.read()

    file_list = json.loads(json_data)
    deletion_file_list = deletion_filter(file_list['files'])

    for file_item in deletion_file_list:
        print file_item['fileId']
