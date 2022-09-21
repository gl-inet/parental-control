#include <linux/init.h>
#include <linux/module.h>
#include <linux/version.h>
#include <linux/proc_fs.h>
#include <linux/inet.h>
#include <linux/if_ether.h>
#include <linux/etherdevice.h>
#include "pc_policy.h"

struct list_head pc_rule_head = LIST_HEAD_INIT(pc_rule_head);
struct list_head pc_group_head = LIST_HEAD_INIT(pc_group_head);

DEFINE_RWLOCK(pc_policy_lock);


int add_pc_rule(const char *id,  unsigned int apps[MAX_APP_IN_RULE], enum pc_action action)
{
    pc_rule_t *rule = NULL;
    rule = kzalloc(sizeof(pc_rule_t), GFP_KERNEL);
    if (rule == NULL) {
        printk("malloc pc_rule_t memory error\n");
        return -1;
    } else {
        memcpy(rule->id, id, RULE_ID_SIZE);
        memcpy(rule->apps, apps, MAX_APP_IN_RULE);
        rule->action = action;
        rule->refer_count = 0;
        pc_policy_write_lock();
        list_add(&rule->head, &pc_rule_head);
        pc_policy_write_unlock();
    }
    return 0;
}

int remove_pc_rule(const char *id)
{
    pc_rule_t *rule = NULL, *n;
    if (!list_empty(&pc_rule_head)) {
        list_for_each_entry_safe(rule, n, &pc_rule_head, head) {
            if (strcmp(rule->id, id) == 0) {
                if (rule->refer_count > 0) {
                    printk("refer_count of rule != 0\n");
                    return -1;
                }
                pc_policy_write_lock();
                list_del(&rule->head);
                kfree(rule);
                pc_policy_write_unlock();
            }
        }
    }
    return 0;
}

int clean_pc_rule(void)
{
    pc_rule_t *rule = NULL;
    pc_policy_write_lock();
    while (!list_empty(&pc_rule_head)) {
        rule = list_first_entry(&pc_rule_head, pc_rule_t, head);
        list_del(&rule->head);
        kfree(rule);
    }
    pc_policy_write_unlock();
    return 0;
}

int set_pc_rule(const char *id, unsigned int apps[MAX_APP_IN_RULE], enum pc_action action)
{
    pc_rule_t *rule = NULL, *n;
    if (!list_empty(&pc_rule_head)) {
        list_for_each_entry_safe(rule, n, &pc_rule_head, head) {
            if (strcmp(rule->id, id) == 0) {
                pc_policy_write_lock();
                memcpy(rule->id, id, RULE_ID_SIZE);
                memcpy(rule->apps, apps, MAX_APP_IN_RULE);
                rule->action = action;
                pc_policy_write_unlock();
            }
        }
    }
    return 0;
}

pc_rule_t *find_rule_by_id(const char *id)
{
    pc_rule_t *rule = NULL, *n;
    pc_rule_t *ret = NULL;
    pc_policy_read_lock();
    if (!list_empty(&pc_rule_head)) {
        list_for_each_entry_safe(rule, n, &pc_rule_head, head) {
            if (strcmp(rule->id, id) == 0) {
                ret = rule;
                goto out;
            }
        }
    }
out:
    pc_policy_read_unlock();
    return ret;
}

int add_pc_group(const char *id,  u8 macs[MAX_MAC_IN_GROUP][ETH_ALEN], const char *rule_id)
{
    pc_group_t *group = NULL;
    pc_rule_t *rule = NULL;
    group = kzalloc(sizeof(pc_group_t), GFP_KERNEL);
    if (group == NULL) {
        printk("malloc pc_group_t memory error\n");
        return -1;
    } else {
        memcpy(group->id, id, GROUP_ID_SIZE);
        memcpy(group->macs, macs, sizeof(group->macs));
        rule = find_rule_by_id(rule_id);
        group->rule = rule;
        pc_policy_write_lock();
        if (rule) {
            rule->refer_count += 1;//增加规则引用计数
        }
        list_add(&group->head, &pc_group_head);
        pc_policy_write_unlock();
    }
    return 0;
}

int remove_pc_group(const char *id)
{
    pc_group_t *group = NULL, *n;
    pc_rule_t *rule = NULL;
    if (!list_empty(&pc_group_head)) {
        list_for_each_entry_safe(group, n, &pc_group_head, head) {
            if (strcmp(group->id, id) == 0) {
                rule = group->rule;
                pc_policy_write_lock();
                if (rule)
                    rule->refer_count -= 1;
                list_del(&group->head);
                kfree(group);
                pc_policy_write_unlock();
            }
        }
    }
    return 0;
}

int clean_pc_group(void)
{
    pc_group_t *group = NULL;
    pc_rule_t *rule = NULL;
    pc_policy_write_lock();
    while (!list_empty(&pc_group_head)) {
        group = list_first_entry(&pc_group_head, pc_group_t, head);
        {
            rule = group->rule;
            if (rule)
                rule->refer_count -= 1;
            list_del(&group->head);
            kfree(group);
        }
    }
    pc_policy_write_unlock();
    return 0;
}

int set_pc_group(const char *id,  u8 macs[MAX_MAC_IN_GROUP][ETH_ALEN], const char *rule_id)
{
    pc_group_t *group = NULL, *n;
    pc_rule_t *rule = NULL;
    rule = find_rule_by_id(rule_id);
    PC_DEBUG("set rule %s for group %s\n", rule ? rule->id : "NULL", id);
    if (!list_empty(&pc_group_head)) {
        list_for_each_entry_safe(group, n, &pc_group_head, head) {
            if (strcmp(group->id, id) == 0) {
                PC_DEBUG("match group %s\n", group->id);
                pc_policy_write_lock();
                memcpy(group->macs, macs, sizeof(group->macs));
                if (group->rule)
                    group->rule->refer_count -= 1;//减少旧规则的引用计数
                group->rule = rule;
                if (rule)
                    rule->refer_count += 1;//增加被引用规则的引用计数
                pc_policy_write_unlock();
            }
        }
    }
    return 0;
}

static pc_group_t *_find_group_by_mac(u8 mac[ETH_ALEN])
{
    pc_group_t *group = NULL, *n;
    int i = 0;
    if (!list_empty(&pc_group_head)) {
        list_for_each_entry_safe(group, n, &pc_group_head, head) {
            for (i = 0; i < MAX_MAC_IN_GROUP; i++) {
                if (ether_addr_equal(group->macs[i], mac)) {
                    return group;
                }
            }
        }
    }
    return NULL;
}

pc_group_t *find_group_by_mac(u8 mac[ETH_ALEN])
{
    pc_group_t *ret = NULL;
    pc_policy_read_lock();
    ret = _find_group_by_mac(mac);
    pc_policy_read_unlock();
    return ret;
}

enum pc_action get_action_by_mac(u8 mac[ETH_ALEN])
{

    pc_group_t *group;
    pc_rule_t *rule;
    enum pc_action action;

    pc_policy_read_lock();
    group = _find_group_by_mac(mac);
    if (!group) { //TODO 设备不属于任何分组，直接通过
        action = PC_ACCEPT;
        goto EXIT;
    }
    rule = group->rule;
    if (!rule) { //TODO 设备组没有设置任何规则，直接通过
        action = PC_ACCEPT;
        goto EXIT;
    }
    action = rule->action;
EXIT:
    pc_policy_read_unlock();
    return action;
}

int get_rule_by_mac(u8 mac[ETH_ALEN], pc_rule_t *rule_ret)
{
    int ret = -1;
    pc_group_t *group;
    pc_rule_t *rule;

    pc_policy_read_lock();
    group = _find_group_by_mac(mac);
    if (!group) {
        goto EXIT;
    }
    rule = group->rule;
    if (!rule) {
        goto EXIT;
    }
    *rule_ret = *rule;
    ret = 0;
EXIT:
    pc_policy_read_unlock();
    return ret;
}

static int rule_proc_show(struct seq_file *s, void *v)
{
    pc_rule_t *rule = NULL, *n;
    int i = 0;
    seq_printf(s, "ID\tAction\tRefer_count\tAPPs\n");
    pc_policy_read_lock();
    if (!list_empty(&pc_rule_head)) {
        list_for_each_entry_safe(rule, n, &pc_rule_head, head) {
            seq_printf(s, "%s\t%d\t%d\t[ ", rule->id, rule->action, rule->refer_count);
            for (i = 0; i < MAX_APP_IN_RULE; i++) {
                if (rule->apps[i] == 0)
                    break;
                seq_printf(s, "%d ", rule->apps[i]);
            }
            seq_printf(s, "]\n");
        }
    }
    pc_policy_read_unlock();
    return 0;
}

static int rule_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, rule_proc_show, NULL);
}

static int group_proc_show(struct seq_file *s, void *v)
{
    pc_group_t *group = NULL, *n;
    int i = 0;
    seq_printf(s, "ID\tRule_ID\tMACs\n");
    pc_policy_read_lock();
    if (!list_empty(&pc_group_head)) {
        list_for_each_entry_safe(group, n, &pc_group_head, head) {
            seq_printf(s, "%s\t%s\t[ ", group->id, group->rule ? group->rule->id : "NULL");
            for (i = 0; i < MAX_MAC_IN_GROUP; i++) {
                if (is_zero_ether_addr(group->macs[i]))
                    break;
                seq_printf(s, "%pM ", group->macs[i]);
            }
            seq_printf(s, "]\n");
        }
    }
    pc_policy_read_unlock();
    return 0;
}

static int group_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, group_proc_show, NULL);
}

static int app_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, app_proc_show, NULL);
}

#if LINUX_VERSION_CODE <= KERNEL_VERSION(5, 5, 0)
static const struct file_operations pc_app_fops = {
    .owner = THIS_MODULE,
    .open = app_proc_open,
    .read = seq_read,
    .llseek = seq_lseek,
    .release = seq_release_private,
};
static const struct file_operations pc_rule_fops = {
    .owner = THIS_MODULE,
    .open = rule_proc_open,
    .read = seq_read,
    .llseek = seq_lseek,
    .release = seq_release_private,
};
static const struct file_operations pc_group_fops = {
    .owner = THIS_MODULE,
    .open = group_proc_open,
    .read = seq_read,
    .llseek = seq_lseek,
    .release = seq_release_private,
};
#else
static const struct proc_ops pc_app_fops = {
    .proc_flags = PROC_ENTRY_PERMANENT,
    .proc_read = seq_read,
    .proc_open = app_proc_open,
    .proc_lseek = seq_lseek,
    .proc_release = seq_release_private,
};
static const struct proc_ops pc_rule_fops = {
    .proc_flags = PROC_ENTRY_PERMANENT,
    .proc_read = seq_read,
    .proc_open = rule_proc_open,
    .proc_lseek = seq_lseek,
    .proc_release = seq_release_private,
};
static const struct proc_ops pc_group_fops = {
    .proc_flags = PROC_ENTRY_PERMANENT,
    .proc_read = seq_read,
    .proc_open = group_proc_open,
    .proc_lseek = seq_lseek,
    .proc_release = seq_release_private,
};
#endif



int init_rule_procfs(void)
{
    struct proc_dir_entry *proc;
    proc = proc_mkdir("parental-control", NULL);
    if (!proc) {
        pr_err("can't create dir /proc/parental-control/\n");
        return -ENODEV;;
    }
    proc_create("rule", 0644, proc, &pc_rule_fops);
    proc_create("group", 0644, proc, &pc_group_fops);
    proc_create("app", 0644, proc, &pc_app_fops);
    return 0;
}

MODULE_LICENSE("GPL");
MODULE_AUTHOR("luochognjun@gl-inet.com");
MODULE_DESCRIPTION("parental control module");
MODULE_VERSION("1.0");

static int __init pc_policy_init(void)
{
    if (pc_load_app_feature_list())
        return -1;
    if (pc_register_dev())
        goto free_app;
    if (pc_filter_init())
        goto free_dev;
    init_rule_procfs();
    return 0;

free_dev:
    pc_unregister_dev();
free_app:
    pc_clean_app_feature_list();
    return -1;
}

static void pc_policy_exit(void)
{
    remove_proc_subtree("parental-control", NULL);
    pc_filter_exit();
    pc_unregister_dev();
    clean_pc_group();
    clean_pc_rule();
    pc_clean_app_feature_list();
    return;
}

module_init(pc_policy_init);
module_exit(pc_policy_exit);