# Note that this assumes a default disk location. Best to verify if it's unknown
{
  disko.devices = {
    disk = {
      my-disk = {
        device = "/dev/sda"; # adjust target disk as needed
	type = "disk";
	content = {
	  type = "gpt";
	  partitions = {
	    ESP = {
	      type = "EF00";
	      size = "500M";
	      content = {
	        type = "filesystem";
		format = "vfat";
		mountpoint = "/boot";
		mountOptions = [ "umask=0077" ];
	      };
	    };
	    root = {
	      size = "100%";
	      content = {
	        type = "filesystem";
		format = "ext4";
		mountpoint = "/";
	      };
	    };
	  };
	};
      };
    };
  };
}
