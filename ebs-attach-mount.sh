#!/bin/bash

# Parse input arguments
while [[ $# > 1 ]]
do
key="$1"

# Parse arguments
case $key in
  -m|--mount-point)
  MOUNT="$2"
  shift # past argument
  ;;
  *)
    # unknown option
  ;;
esac
shift
done

# Detect free block device
function detect_free_block_device {  
  for x in {a..z}
  do
    DEVICE="/dev/xvd$x"
    if [ ! -b $DEVICE ]
    then
      break
    fi
  done
}

VOLUME_NAME=$ECS_CLUSTER-$CONTAINER
$VOLUME=$(aws ec2 describe-volumes --region us-west-1 --filters Name=tag-key,Values=Name Name=tag-value,Values=$VOLUME_NAME --query 'Volumes[0].VolumeId')

# Attach and mount volume
function attach_and_mount_volume {
  # Get instance id
  INSTANCE=$(curl http://169.254.169.254/latest/meta-data/instance-id)
  # Extract region
  REGION=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
  echo Instance ID is $INSTANCE
  
  if ! aws ec2 attach-volume --volume-id $VOLUME --instance-id $INSTANCE --device $DEVICE --region $REGION
  then
    exit 1
  fi
  echo Attaching volume as $DEVICE

  # Waiting for volume to be attached
  while [ ! -b $DEVICE ]
  do
    sleep 2
  done

  # Create directory
  mkdir -p $MOUNT
  # Mount volume
  mount $DEVICE $MOUNT
  echo Mounted volume as $MOUNT
}

# Detach volume
function detach {
  # Detach volume
  echo Unmounting and detaching volume
  umount $MOUNT
  aws ec2 detach-volume --volume-id $VOLUME --region $REGION
}

# Run steps
detect_free_block_device
attach_and_mount_volume
trap detach EXIT

# Run infinite loop
while :
do
  sleep 60
done
