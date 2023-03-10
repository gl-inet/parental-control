#ifndef PC_UTILS_H
#define PC_UTILS_H
u_int32_t pc_get_timestamp_sec(void);

char *k_trim(char *s);

int check_local_network_ip(unsigned int ip);

void dump_str(char *name, unsigned char *p, int len);

void dump_hex(char *name, unsigned char *p, int len);

int k_sscanf(const char *buf, const char *fmt, ...);

#endif

