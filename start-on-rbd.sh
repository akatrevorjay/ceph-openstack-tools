#!/bin/bash
set -e

DIR=`dirname $0`
DEVSTACK_DIR=${DEVSTACK_DIR:-~/devstack}

if [ ! -f $DIR/debian.img ]; then
	echo "Downloading debian image..."
	wget http://ceph.newdream.net/qa/debian.img -O $DIR/debian.img
fi
touch $DIR/dummy_img
glance-upload --disk-format raw $DIR/dummy_img dummy_raw_img

FIXED_RANGE="192.168.0.0/24" FLOATING_RANGE="192.168.0.0/27" sudo $DEVSTACK_DIR/stack.sh

echo "Waiting for image to become available..."
sudo chown ubuntu:ubuntu ~/openstack/nova/novarc
source ~/openstack/nova/novarc
while true; do
	if ( timeout 5 euca-describe-images | egrep -q "dummy_raw_img\)\s+available" ) then
		break
	fi
	sleep 2
done

echo "Creating volume..."
euca-create-volume -s 1 -z nova
echo "Waiting for volume to be available..."
while true; do
	if ( euca-describe-volumes | egrep -q "vol-00000001\s+1\s+nova\s+available" ) then
		break
	fi
	sleep 2
done

echo "Replacing blank image with real one..."
rbd rm volume-00000001
rbd import $DIR/debian.img volume-00000001
echo "Requesting an instance..."
$DIR/boot-from-volume
echo "Waiting for instance to start..."
while true; do
	if ( euca-describe-instances | grep -q "i-00000001.*running" ) then
		break
	fi
	sleep 2
done
cat <<EOF
Instance is running. You can attach to it with:
    vncviewer 0.0.0.0:5900

To interact with openstack,
    sudo screen -S stack -x

To stop openstack:
    sudo screen -S stack -X quit
EOF
