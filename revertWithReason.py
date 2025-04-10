def cal(s):
    s = s.encode('utf-8').hex()
    l = hex(len(s)//2)
    s = '000000' + l[2:] + s
    ll = len(s)//2
    for i in range(ll,32):
        s = s+'00'
    return s,len(s)//2,hex(64+ll)
# print(cal('invalid msg.value'))
print(cal("InvalidSignatureS"))