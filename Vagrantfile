# One Rocky Linux 9 VM (RHEL-compatible) that Ansible turns into the CI/CD lab.
# Works with VirtualBox; for VMware Workstation set provider to "vmware_desktop".
Vagrant.configure("2") do |config|
  config.vm.box      = "bento/rockylinux-9"
  config.vm.hostname = "devops-lab"
  config.vm.network "private_network", ip: "192.168.56.10"

  # Sizing: k3s ~1 GB, Jenkins ~1-1.5 GB, Docker builds + registry ~1 GB, OS ~0.5 GB
  # -> 6 GB RAM leaves some headroom.
  config.vm.provider "virtualbox" do |vb|
    vb.name   = "devops-lab"
    vb.memory = 6144
    vb.cpus   = 2
  end

  # Ansible runs *inside* the VM, so this also works from Windows without WSL.
  config.vm.provision "ansible_local" do |ansible|
    ansible.provisioning_path = "/vagrant/ansible"
    ansible.playbook          = "site.yml"
    ansible.inventory_path    = "inventory/local.ini"
    ansible.galaxy_role_file  = "requirements.yml"
    ansible.limit             = "all"
    ansible.install_mode      = "pip"
  end
end
