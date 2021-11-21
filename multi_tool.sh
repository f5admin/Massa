#!/bin/bash
# Default variables
function="install"
source="false"

# Options
. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/colors.sh) --
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
	case "$1" in
	-h|--help)
		. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/logo.sh)
		echo
		echo -e "${C_LGn}Functionality${RES}: the script installs, updates a Massa node, and opens required ports"
		echo
		echo -e "${C_LGn}Usage${RES}: script ${C_LGn}[OPTIONS]${RES}"
		echo
		echo -e "${C_LGn}Options${RES}:"
		echo -e "  -h, --help         show the help page"
		echo -e "  -op, --open-ports  open required ports"
		echo -e "  -s, --source       install the node using a source code"
		echo
		echo -e "You can use either \"=\" or \" \" as an option and value ${C_LGn}delimiter${RES}"
		echo
		echo -e "${C_LGn}Useful URLs${RES}:"
		echo -e "https://github.com/Kallen-c/Massa/blob/main/multi_tool.sh - script URL"
		echo
		return 0
		;;
	-op|--open-ports)
		function="open_ports"
		shift
		;;
	-s|--source)
		function="install_source"
		shift
		;;
	*|--)
		break
		;;
	esac
done

# Functions
printf_n(){ printf "$1\n" "${@:2}"; }
open_ports() {
	sudo systemctl stop massad
	. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/miscellaneous/ports_opening.sh) 31244 31245
	sudo tee <<EOF >/dev/null $HOME/Massa/massa/massa-node/config/config.toml
[network]
routable_ip = "`wget -qO- eth0.me`"
EOF
	sudo apt install net-tools -y
	netstat -ntlp | grep "massa-node"
	sudo systemctl restart massad
}
update() {
	printf_n "${C_LGn}Node updating...${RES}"
	if [ ! -d $HOME/Massa/massa_backup ]; then
		mkdir $HOME/Massa/massa_backup
		sudo cp $HOME/Massa/massa/massa-client/wallet.dat $HOME/Massa/massa_backup/wallet.dat
		sudo cp $HOME/Massa/massa/massa-node/config/node_privkey.key $HOME/Massa/massa_backup/node_privkey.key
	fi
	wget -qO massa.zip https://gitlab.com/massalabs/massa/-/jobs/artifacts/testnet/download?job=build-linux
	if [ `wc -c < "massa.zip"` -ge 1000 ]; then
		rm -rf $HOME/Massa/massa/
		unzip massa.zip
		chmod +x $HOME/Massa/massa/massa-node/massa-node $HOME/Massa/massa/massa-client/massa-client
		printf "[Unit]
Description=Massa Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/Massa/massa/massa-node
ExecStart=$HOME/Massa/massa/massa-node/massa-node
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/massad.service
		sudo systemctl enable massad
		sudo systemctl daemon-reload
		sudo cp $HOME/Massa/massa_backup/node_privkey.key $HOME/Massa/massa/massa-node/config/node_privkey.key
		sed -i -e "s%^bind_private *=.*%bind_private = \"127.0.0.1:33034\"%; s%^bind_public *=.*%bind_public = \"0.0.0.0:33035\"%;" "$HOME/Massa/massa/massa-node/base_config/config.toml"
		sed -i -e "s%.*ip *=.*%ip = \"127.0.0.1\"%;" "$HOME/Massa/massa/massa-client/base_config/config.toml"
		open_ports
		cd $HOME/Massa/massa/massa-client/
		sudo cp $HOME/Massa/massa_backup/wallet.dat $HOME/Massa/massa/massa-client/wallet.dat
		. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/Massa/main/insert_variables.sh)
		cd
		printf_n "${C_LGn}Done!${RES}\n"
	else
		printf_n "${C_LR}Archive with binary downloaded unsuccessfully${RES}\n"
	fi
	rm -rf massa.zip
}
install() {
	if [ -d $HOME/Massa/massa/ ]; then
		update
	else
		sudo apt update
		sudo apt upgrade -y
		sudo apt install unzip jq curl pkg-config git build-essential libssl-dev -y
		printf_n "${C_LGn}Node installation...${RES}"
		wget -qO massa.zip https://gitlab.com/massalabs/massa/-/jobs/artifacts/testnet/download?job=build-linux
		if [ `wc -c < "massa.zip"` -ge 1000 ]; then
			unzip massa.zip
			rm -rf massa.zip
			printf "[Unit]
Description=Massa Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/Massa/massa/massa-node
ExecStart=$HOME/Massa/massa/massa-node/massa-node
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/massad.service
			sudo systemctl enable massad
			sudo systemctl daemon-reload
			sed -i -e "s%^bind_private *=.*%bind_private = \"127.0.0.1:33034\"%; s%^bind_public *=.*%bind_public = \"0.0.0.0:33035\"%;" "$HOME/Massa/massa/massa-node/base_config/config.toml"
			sed -i -e "s%.*ip *=.*%ip = \"127.0.0.1\"%;" "$HOME/Massa/massa/massa-client/base_config/config.toml"
			open_ports
			cd $HOME/Massa/massa/massa-client/
			if [ ! -d $HOME/Massa/massa_backup ]; then
				./massa-client wallet_generate_private_key
			else
				sudo cp $HOME/Massa/massa_backup/node_privkey.key $HOME/Massa/massa/massa-node/config/node_privkey.key
				sudo systemctl restart massad
				sudo cp $HOME/Massa/massa_backup/wallet.dat $HOME/Massa/massa/massa-client/wallet.dat
			fi
			#local wallet_address="null"
			#while [ "$wallet_address" = "null" ]; do
			#	local wallet_address=$(./massa-client --cli true wallet_info | jq -r ".balances | keys[-1]")
			#done
			#. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/miscellaneous/insert_variable.sh) -n "massa_wallet_address" -v "$wallet_address"
			. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/Massa/main/insert_variables.sh)
			if [ ! -d $HOME/Massa/massa_backup ]; then
				mkdir $HOME/Massa/massa_backup
				sudo cp $HOME/Massa/massa/massa-client/wallet.dat $HOME/Massa/massa_backup/wallet.dat
				sudo cp $HOME/Massa/massa/massa-node/config/node_privkey.key $HOME/Massa/massa_backup/node_privkey.key
			fi
			printf_n "${C_LGn}Done!${RES}"
			cd
			. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/logo.sh)
			printf_n "
The node was ${C_LGn}started${RES}.

Remember to save files in this directory:
${C_LR}$HOME/Massa/massa_backup/${RES}

\tv ${C_LGn}Useful commands${RES} v

To start a client: ${C_LGn}massa_client${RES}
To view the node status: ${C_LGn}sudo systemctl status massad${RES}
To view the node log: ${C_LGn}massa_log${RES}
To restart the node: ${C_LGn}sudo systemctl restart massad${RES}
"
		else
			rm -rf massa.zip
			printf_n "${C_LR}Archive with binary downloaded unsuccessfully!${RES}\n"
		fi
	fi
}
install_source() {
	if [ -d $HOME/Massa/massa/ ]; then
		printf_n "${C_LR}Node already installed!${RES}"
	else
		sudo apt update
		sudo apt upgrade -y
		sudo apt install unzip jq curl pkg-config git build-essential libssl-dev -y
		printf_n "${C_LGn}Node installation...${RES}"
		. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/installers/rust.sh) -n
		if [ ! -d $HOME/Massa/massa/ ]; then
			git clone --branch testnet https://gitlab.com/massalabs/massa.git
		fi
		cd $HOME/Massa/massa/massa-node/
		RUST_BACKTRACE=full cargo build --release
		printf "[Unit]
Description=Massa Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/Massa/massa/massa-node
ExecStart=$HOME/Massa/massa/target/release/massa-node
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/massad.service
		sudo systemctl enable massad
		sudo systemctl daemon-reload
		sed -i -e "s%^bind_private *=.*%bind_private = \"127.0.0.1:33034\"%; s%^bind_public *=.*%bind_public = \"0.0.0.0:33035\"%;" "$HOME/Massa/massa/massa-node/base_config/config.toml"
		sed -i -e "s%.*ip *=.*%ip = \"127.0.0.1\"%;" "$HOME/Massa/massa/massa-client/base_config/config.toml"
		open_ports
		printf_n "
${C_LGn}Done!${RES}
${C_LGn}Client installation...${RES}
"
		cd $HOME/Massa/massa/massa-client/
		cargo run --release wallet_new_privkey
		#massa_wallet_address=$(cargo run --release -- --cli true wallet_info | jq -r ".balances | keys[]")
		#. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/miscellaneous/insert_variable.sh) -n massa_log -v "sudo journalctl -f -n 100 -u massad" -a
	fi
	printf_n "${C_LGn}Done!${RES}"
	cd
	. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/logo.sh)
	printf_n "
The node was ${C_LGn}started${RES}.

Remember to save files in this directory:
${C_LR}$HOME/Massa/massa_backup/${RES}

\tv ${C_LGn}Useful commands${RES} v

To start a client: ${C_LGn}massa_client${RES}
To view the node status: ${C_LGn}sudo systemctl status massad${RES}
To view the node log: ${C_LGn}massa_log${RES}
To restart the node: ${C_LGn}sudo systemctl restart massad${RES}
"
}


# Actions
sudo apt install wget -y
. <(wget -qO- https://raw.githubusercontent.com/Kallen-c/utils/main/logo.sh)
cd
$function