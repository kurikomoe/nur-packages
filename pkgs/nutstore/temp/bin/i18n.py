import os
import locale

ROOT_PATH = os.path.dirname(os.path.abspath(__file__))
COMMENT_CHAR = '#'
TRANSLATE_SEPARATOR = "="
LANGUAGE_DIR = "resource/locale"
LANGUAGE_FILE_SUFFIX = ".txt"


class I18N(object):
    strings_ = None

    @staticmethod
    def get(key):
        if I18N.strings_ is None:
            I18N.strings_ = I18N.load()
        return I18N.strings_.get(key, key)

    @staticmethod
    def load():
        lang = locale.getdefaultlocale()[0]
        file_path = os.path.join(ROOT_PATH, LANGUAGE_DIR, lang+LANGUAGE_FILE_SUFFIX)
        if not os.path.exists(file_path):
            return {}
        tmp_string = {}
        lines = open(file_path).readlines()
        for line in lines:
            line = line.strip()
            if len(line) and not line.startswith(COMMENT_CHAR):
                ori, trans = line.split(TRANSLATE_SEPARATOR)
                tmp_string[ori] = trans
        return tmp_string
