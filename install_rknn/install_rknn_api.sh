#!/usr/bin/env bash

function set_usb_permission()
{
cat <<EOF > "91-rk1808-ai-cs.rules"
	SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666"
EOF
	sudo cp -f 91-rk1808-ai-cs.rules /etc/udev/rules.d/
	sudo udevadm control --reload-rules
	sudo udevadm trigger
	sudo ldconfig
	rm 91-rk1808-ai-cs.rules
}

function download_rknn_api()
{
	rm -rf rknn_api
	if [ ${DISTRO} == 'MacOS' ]; then
		PLATFORM='MacOS'
	else
		PLATFORM='Linux'
	fi

	wget -r -np -nc -nH http://repo.rock-chips.com/rk1808/rknn-api/${PLATFORM}/rknn_api_sdk/rknn_api/
	rm -rf ./rknn_api
	mv ./rk1808/rknn-api/${PLATFORM}/rknn_api_sdk/rknn_api ./
	rm -rf ./rk1808
	find ./rknn_api -type f -name "index.html" -exec rm -rf {} \;
}

if [ `uname -m` == "x86_64" ]; then
        RKNN_DIR="x86"
        NPU_PROXY_DIR="linux-x86_64"
elif [ `uname -m` == "aarch64" ]; then
        RKNN_DIR="arm"
        NPU_PROXY_DIR="linux-aarch64"
else
        RKNN_DIR="unknown"
        NPU_PROXY_DIR="unknown"
fi

if [ ! -z "`sw_vers | grep Mac`" ]; then
	DISTRO="MacOS"
	LIB_DIR="/local/lib/"
	NPU_PROXY_DIR="macos-x86_64"
elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
	DISTRO="Fedora"
	LIB_DIR="lib64"
elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
	DISTRO="Ubuntu"
	LIB_DIR="lib"
else
	DISTRO="unknown"
	LIB_DIR="unknown"
fi

if [ ${DISTRO} == "unknown" ]; then
	echo "this script only support Fedora and Ubuntu!"
	exit 1
fi

if [ ${RKNN_DIR} == "unknown" ]; then
	echo "unsupport CPU arch!"
	exit 1
fi

echo "================================="
echo Distro: $DISTRO
echo rknn dir: $RKNN_DIR
echo npu proxy dir: $NPU_PROXY_DIR
echo lib dir: $LIB_DIR
echo "================================="

download_rknn_api

rm -rf npu_transfer_proxy
wget -P npu_transfer_proxy http://repo.rock-chips.com/rk1808/npu_transfer_proxy/${NPU_PROXY_DIR}/npu_transfer_proxy

echo "kill npu_transfer_proxy pid = $(pgrep npu_transfer)"
pkill npu_transfer

if [ ${DISTRO} == 'MacOS' ]; then
	cp rknn_api/${RKNN_DIR}/lib64/librknn_api.dylib /usr/${LIB_DIR}/
	chmod 755 /usr/${LIB_DIR}/librknn_api.dylib

	if [ ! -d "/usr/local/include/rockchip" ];then
		mkdir /usr/local/include/rockchip
	fi

	cp rknn_api/${RKNN_DIR}/include/rknn_api.h /usr/local/include/rockchip
	cp npu_transfer_proxy/npu_transfer_proxy /usr/local/bin/
	chmod 755 /usr/local/bin/npu_transfer_proxy
else
	set_usb_permission

	#chmod 755 ./script/npud
	#cp ./script/npud /etc/init.d/
	#chmod 755 /etc/init.d/npud
	#update-rc.d npud defaults 90

	cp rknn_api/${RKNN_DIR}/lib64/librknn_api.so /usr/${LIB_DIR}/
	chmod 755 /usr/${LIB_DIR}/librknn_api.so

	if [ ! -d "/usr/include/rockchip" ];then
		mkdir /usr/include/rockchip
	fi

	cp rknn_api/${RKNN_DIR}/include/rknn_api.h /usr/include/rockchip
	cp npu_transfer_proxy/npu_transfer_proxy /usr/bin/
	chmod 755 /usr/bin/npu_transfer_proxy

	#/etc/init.d/npud start
fi

exit 0
