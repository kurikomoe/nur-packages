import os

ROOT_PATH = os.path.dirname(os.path.abspath(__file__))
RESOURCE_DIR = os.path.join(ROOT_PATH, "resource")
TRAY_DIR = os.path.join(RESOURCE_DIR, "tray_pics")


class PicturesManage:
    NONE = "NONE"
    NORMAL = "NORMAL"
    PAUSED = "PAUSED"
    OOPS = "OOPS"
    OFFLINE = "OFFLINE"
    SYNCING = "SYNCING"
    SYNCED = "SYNCED"


    tray_map = {
        NORMAL: "nutstore.png",
        OFFLINE: "offline.png",
        OOPS: "oops.png",
        PAUSED: "paused.png",
        SYNCING: "synchronizing.png",
        SYNCED: "synchronized.png"
    }

    @staticmethod
    def get_logo():
        return PicturesManage.get_status_pic(PicturesManage.NORMAL)

    @staticmethod
    def get_status_pic(status):
        if status not in PicturesManage.tray_map.keys():
            raise Exception("Invalid Nutstore Sync Status: " + status)
        path = os.path.join(TRAY_DIR, PicturesManage.tray_map.get(status))
        return path
