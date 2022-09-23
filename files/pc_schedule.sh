#!/bin/sh
. /usr/share/libubox/jshn.sh
. /lib/functions.sh
. /lib/functions/parental_control.sh

INTERVAL=60
WEEK_CUR=1
TIME_CUR=0

debug_print()
{
    [ "$DEBUG" = "1" ] || return 0
    logger -t 'parental_control' $@
}

get_current_time()
{
    local d="$(date '+%w %H%M%S')"
    WEEK_CUR="$(echo $d|cut -d ' ' -f 1)"
    TIME_CUR="$(echo $d|cut -d ' ' -f 2)"
    debug_print "current time is week=$WEEK_CUR time=$TIME_CUR"
}

time_in_range()
{
    local week=$1
    local week_match=0
    for w in $week; do
        [ "$WEEK_CUR" -eq "$w" ] && { week_match=1;break; }
    done
    [ "$week_match" -ne "1" ] && return 1
    local begin="$(echo $2|awk -F: '{printf $1$2$3}')"
    local end="$(echo $3|awk -F: '{printf $1$2$3}')"
    [ "$TIME_CUR" -ge "$begin" ] && [ "$TIME_CUR" -le "$end" ] && return 0
    return 1
}

get_current_status()
{
    local id rule
    while read -r line; do 
        id="$(echo $line|awk -F ' ' '{print $1}')"
        rule="$(echo $line|awk -F ' ' '{print $2}')"
        [ $id = "ID" -a $rule = 'Rule_ID' ] && continue
        [ -n $id ] && [ -n $rule ] && eval ${id}_status=$rule
    done < /proc/parental-control/group
}

group_default_rule()
{
    group_default_cb(){
        local id=$1
        local rule 
        config_get rule "$id" "default_rule"
        [ -n "$rule" ] && {
            eval ${id}_rule=\$rule
        }
    }
    config_foreach group_default_cb group
}

is_rule_change()
{
    local group=$1
    local new=$2
    local old

    eval old=\$${group}_status
    [ $old = $new ] && return 1
    return 0
}

do_set_groups_rule()
{
    local change=0
    json_init
    json_add_int "op" $SET_GROUP
    json_add_object "data"
    json_add_array "groups"

    set_groups_cb(){
        local id=$1
        local rule macs
        eval rule=\$${id}_rule
        is_rule_change $id $rule || return 0
        change=1
        debug_print "rule change,group $id use rule $rule"
        config_get macs "$id" "macs"
        json_add_object ""
        json_add_string "id" "$id"
        json_add_string "rule" $rule
        [ -n "$macs" ] && {
            json_add_array "macs"
            for mac in $macs;do
                json_add_string "" $mac
            done
            json_select ..
        }
        json_select ..
    }
    config_foreach set_groups_cb group

    json_str=`json_dump`
    [ "$change" -eq 1 ] && config_apply "$json_str"
    json_cleanup
}

schedule_for_each()
{
    load_schedule_cb(){
        local config=$1
        local week begin end rule group
        config_get week "$config" "week"
        config_get begin "$config" "begin"
        config_get end "$config" "end"
        config_get group "$config" "group"
        
        time_in_range "$week" "$begin" "$end" && {
            config_get group "$config" "group"
            config_get rule "$config" "rule"
            eval ${group}_rule=\$rule
            debug_print "time is in range $week from $begin to $end"
        }
    }
    group_default_rule
    config_foreach  load_schedule_cb schedule
    do_set_groups_rule
}

init_parental_control()
{
    load_base_config
    clean_group
    clean_rule
    load_rule
    load_group
}

config_load parental_control
init_parental_control
while true;do
    get_current_status
    get_current_time
    schedule_for_each
    sleep $INTERVAL
done

exit 0