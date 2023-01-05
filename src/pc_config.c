
#include <linux/init.h>
#include <linux/module.h>
#include <linux/cdev.h>
#include <linux/vmalloc.h>
#include <linux/device.h>
#include <linux/if_ether.h>
#include <linux/etherdevice.h>
#include "cJSON.h"
#include "pc_policy.h"

#define PC_DEV_NAME "parental_control"

u8 pc_drop_anonymous = 0;
char pc_src_dev[MAX_SRC_DEVNAME_SIZE] = {0};

static struct mutex pc_cdev_mutex;

struct pc_config_dev {
    dev_t id;
    struct cdev char_dev;
    struct class *c;
};
struct pc_config_dev g_pc_dev;

struct pc_cdev_file {
    size_t size;
    char buf[256 << 10];
};

enum PC_CONFIG_CMD {
    PC_CMD_SET_BASE = 0,
    PC_CMD_ADD_RULE,
    PC_CMD_ADD_GROUP,
    PC_CMD_CLEAN_RULE,
    PC_CMD_CLEAN_GROUP,
    PC_CMD_SET_RULE,
    PC_CMD_SET_GROUP,
};

static int mac_to_hex(u8 *mac, u8 *mac_hex)
{
    u32 mac_tmp[ETH_ALEN];
    int ret = 0, i = 0;
    ret = sscanf(mac, "%02x:%02x:%02x:%02x:%02x:%02x",
                 (unsigned int *)&mac_tmp[0],
                 (unsigned int *)&mac_tmp[1],
                 (unsigned int *)&mac_tmp[2],
                 (unsigned int *)&mac_tmp[3],
                 (unsigned int *)&mac_tmp[4],
                 (unsigned int *)&mac_tmp[5]);
    if (ETH_ALEN != ret)
        return -1;
    for (i = 0; i < ETH_ALEN; i++) {
        mac_hex[i] = mac_tmp[i];
    }
    return 0;
}

static int pc_set_base_config(cJSON *data_obj)
{
    cJSON *aouobj = NULL, *srcobj = NULL;
    if (!data_obj) {
        PC_ERROR("data obj is null\n");
        return -1;
    }
    aouobj = cJSON_GetObjectItem(data_obj, "drop_anonymous");
    if (!aouobj) {
        PC_ERROR("aouobj obj is null\n");
        return -1;
    }
    pc_drop_anonymous = aouobj->valueint;

    srcobj = cJSON_GetObjectItem(data_obj, "src_dev");
    if (!srcobj) {
        PC_ERROR("srcobj obj is null\n");
        return -1;
    }
    strncpy(pc_src_dev, srcobj->valuestring, MAX_SRC_DEVNAME_SIZE - 1);
    return 0;
}


static int pc_set_rule_config(cJSON *data_obj, char add)
{
    int i;
    cJSON *arr = NULL;
    if (!data_obj) {
        PC_ERROR("data obj is null\n");
        return -1;
    }
    arr = cJSON_GetObjectItem(data_obj, "rules");
    if (!arr) {
        PC_ERROR("rules obj is null\n");
        return -1;
    }
    for (i = 0; i < cJSON_GetArraySize(arr); i++) {
        cJSON *rule_obj = NULL, *id_obj = NULL, *action_obj = NULL;
        cJSON *blacklist = NULL;
        cJSON *applist = NULL;
        rule_obj = cJSON_GetArrayItem(arr, i);
        if (!rule_obj) {
            PC_ERROR("no rule fund\n");
            return -1;
        }
        id_obj = cJSON_GetObjectItem(rule_obj, "id");
        if (!id_obj) {
            PC_ERROR("no rule id fund\n");
            return -1;
        }
        action_obj = cJSON_GetObjectItem(rule_obj, "action");
        if (!action_obj) {
            PC_ERROR("no rule action fund\n");
            return -1;
        }
        applist = cJSON_GetObjectItem(rule_obj, "apps");
        blacklist = cJSON_GetObjectItem(rule_obj, "blacklist");
        if (add)
            add_pc_rule(id_obj->valuestring, applist, action_obj->valueint, blacklist);
        else
            set_pc_rule(id_obj->valuestring, applist, action_obj->valueint, blacklist);
    }

    return 0;
}

static int pc_set_group_config(cJSON *data_obj, char add)
{
    int i, j;
    cJSON *arr = NULL;
    if (!data_obj) {
        PC_ERROR("data obj is null\n");
        return -1;
    }
    arr = cJSON_GetObjectItem(data_obj, "groups");
    if (!arr) {
        PC_ERROR("groups obj is null\n");
        return -1;
    }
    for (i = 0; i < cJSON_GetArraySize(arr); i++) {
        u8 macs[MAX_MAC_IN_GROUP][ETH_ALEN] = {0};
        cJSON *group_obj = NULL, *id_obj = NULL, *rule_obj = NULL, *macs_obj = NULL, *mac_obj = NULL;
        group_obj = cJSON_GetArrayItem(arr, i);
        if (!group_obj) {
            PC_ERROR("no group fund\n");
            return -1;
        }
        id_obj = cJSON_GetObjectItem(group_obj, "id");
        if (!id_obj) {
            PC_ERROR("no group id fund\n");
            return -1;
        }
        rule_obj = cJSON_GetObjectItem(group_obj, "rule");
        if (!rule_obj) {
            PC_ERROR("no rule id action fund\n");
            return -1;
        }
        macs_obj = cJSON_GetObjectItem(group_obj, "macs");
        if (macs_obj) {
            for (j = 0; j < cJSON_GetArraySize(macs_obj) && j < MAX_MAC_IN_GROUP; j++) {
                mac_obj = cJSON_GetArrayItem(macs_obj, j);
                if (mac_obj) {
                    u8 mac_hex[ETH_ALEN] = {0};
                    if (!mac_to_hex(mac_obj->valuestring, mac_hex)) {
                        ether_addr_copy(macs[j], mac_hex);
                    }
                }
            }
        }
        if (add)
            add_pc_group(id_obj->valuestring, macs, rule_obj->valuestring);
        else
            set_pc_group(id_obj->valuestring, macs, rule_obj->valuestring);
    }

    return 0;
}

int pc_config_handle(char *config, unsigned int len)
{
    cJSON *config_obj = NULL;
    cJSON *cmd_obj = NULL;
    cJSON *data_obj = NULL;
    if (!config || len == 0) {
        PC_ERROR("config or len is invalid\n");
        return -1;
    }
    config_obj = cJSON_Parse(config);
    if (!config_obj) {
        PC_ERROR("config_obj is NULL\n");
        return -1;
    }
    cmd_obj = cJSON_GetObjectItem(config_obj, "op");
    if (!cmd_obj) {
        PC_ERROR("not find op object\n");
        return -1;
    }
    data_obj = cJSON_GetObjectItem(config_obj, "data");

    switch (cmd_obj->valueint) {
        case PC_CMD_SET_BASE:
            if (!data_obj)
                break;
            pc_set_base_config(data_obj);
            break;
        case PC_CMD_ADD_RULE:
            if (!data_obj)
                break;
            pc_set_rule_config(data_obj, 1);
            break;
        case PC_CMD_ADD_GROUP:
            if (!data_obj)
                break;
            pc_set_group_config(data_obj, 1);
            break;
        case PC_CMD_CLEAN_RULE:
            clean_pc_rule();
            break;
        case PC_CMD_CLEAN_GROUP:
            clean_pc_group();
            break;
        case PC_CMD_SET_RULE:
            if (!data_obj)
                break;
            pc_set_rule_config(data_obj, 0);
            break;
        case PC_CMD_SET_GROUP:
            if (!data_obj)
                break;
            pc_set_group_config(data_obj, 0);
            break;
        default:
            PC_ERROR("invalid cmd %d\n", cmd_obj->valueint);
            return -1;
    }
    return 0;
}

static int pc_cdev_open(struct inode *inode, struct file *filp)
{
    struct pc_cdev_file *file;
    file = vzalloc(sizeof(*file));
    if (!file)
        return -EINVAL;

    mutex_lock(&pc_cdev_mutex);
    filp->private_data = file;
    return 0;
}

static ssize_t pc_cdev_read(struct file *filp, char *buf, size_t count, loff_t *off)
{
    return 0;
}

static int pc_cdev_release(struct inode *inode, struct file *filp)
{
    struct pc_cdev_file *file = filp->private_data;
    PC_DEBUG("config size: %d,data = %s\n", (int)file->size, file->buf);
    pc_config_handle(file->buf, file->size);
    filp->private_data = NULL;
    mutex_unlock(&pc_cdev_mutex);
    vfree(file);
    return 0;
}

static ssize_t pc_cdev_write(struct file *filp, const char *buffer, size_t count, loff_t *off)
{
    struct pc_cdev_file *file = filp->private_data;
    int ret;
    if (file->size + count > sizeof(file->buf)) {
        PC_ERROR("config overflow, cur_size: %d, block_size: %d, max_size: %d",
                 (int)file->size, (int)count, (int)sizeof(file->buf));
        return -EINVAL;
    }

    ret = copy_from_user(file->buf + file->size, buffer, count);
    if (ret != 0)
        return -EINVAL;

    file->size += count;
    return count;
}

static struct file_operations pc_cdev_ops = {
owner :
    THIS_MODULE,
release :
    pc_cdev_release,
open :
    pc_cdev_open,
write :
    pc_cdev_write,
read :
    pc_cdev_read,
};

int pc_register_dev(void)
{
    struct device *dev;
    int res;

    mutex_init(&pc_cdev_mutex);

    res = alloc_chrdev_region(&g_pc_dev.id, 0, 1, PC_DEV_NAME);
    if (res != 0) {
        return -EINVAL;
    }

    cdev_init(&g_pc_dev.char_dev, &pc_cdev_ops);
    res = cdev_add(&g_pc_dev.char_dev, g_pc_dev.id, 1);
    if (res < 0) {
        goto REGION_OUT;
    }

    g_pc_dev.c = class_create(THIS_MODULE, PC_DEV_NAME);
    if (IS_ERR_OR_NULL(g_pc_dev.c)) {
        goto CDEV_OUT;
    }

    dev = device_create(g_pc_dev.c, NULL, g_pc_dev.id, NULL, PC_DEV_NAME);
    if (IS_ERR_OR_NULL(dev)) {
        goto CLASS_OUT;
    }
    PC_INFO("register parental_control ok\n");

    return 0;

CLASS_OUT:
    class_destroy(g_pc_dev.c);
CDEV_OUT:
    cdev_del(&g_pc_dev.char_dev);
REGION_OUT:
    unregister_chrdev_region(g_pc_dev.id, 1);

    PC_ERROR("register parental_control fail\n");
    return -EINVAL;
}

void pc_unregister_dev(void)
{
    device_destroy(g_pc_dev.c, g_pc_dev.id);
    class_destroy(g_pc_dev.c);
    cdev_del(&g_pc_dev.char_dev);
    unregister_chrdev_region(g_pc_dev.id, 1);
    PC_INFO("unregister parental_control ok\n");
}
