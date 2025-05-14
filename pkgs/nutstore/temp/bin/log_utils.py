import logging
from logging.handlers import RotatingFileHandler
import os
import sys

LOG_LEVEL = logging.INFO
LOG_FILE = os.path.expanduser("~/.nutstore/logs/daemon.log")

# default max log file size = 5MB
MAX_LOG_FILE_SIZE = 5 * 1024 * 1024
BACK_UP_COUNT = 5

FMT = logging.Formatter("%(asctime)s [%(threadName)s] %(funcName)s %(levelname)s: %(message)s")


def get_logger(name=None):
    if name is None:
        import uuid
        name = str(uuid.uuid4())
    # log to stdout
    # https://stackoverflow.com/questions/13733552/logger-configuration-to-log-to-file-and-print-to-stdout
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(FMT)
    logging.getLogger(name).addHandler(console_handler)

    logger = logging.getLogger(name)
    logger.setLevel(LOG_LEVEL)

    dir = os.path.dirname(LOG_FILE)
    if not os.path.exists(dir):
        os.makedirs(dir)
    file_handler = RotatingFileHandler(LOG_FILE, maxBytes=MAX_LOG_FILE_SIZE, backupCount=BACK_UP_COUNT)
    file_handler.setFormatter(FMT)
    logger.addHandler(file_handler)
    return logger

