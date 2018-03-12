# Ansible module to remove the test databases
from ansible.module_utils.basic import *
import MySQLdb

def main():
  module = AnsibleModule(argument_spec=
    dict(rootpw=dict(type="str", required=True)), supports_check_mode=True)
  db=MySQLdb.connect(passwd=module.params["rootpw"], db="mysql")
  c=db.cursor()
  c.execute("select * from db where db like 'test%' and user='';")
  changed=False
  if c.rowcount > 0:
    changed=True
  if module.check_mode:
    c.close();
    module.exit_json(changed=changed)
  if c.rowcount > 0:
    c.execute("delete from db where db like 'test%' and user='';")
    if c.rowcount > 0:
      changed=False
      module.fail_json(changed=False, msg='Failed to remove test databases')
    c.execute("flush privileges;")
    db.commit();
  c.close();
  module.exit_json(changed=True, msg='test databases removed')

if __name__ == '__main__':
  main()
