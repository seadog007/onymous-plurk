#!/bin/bash

function login(){
	read -p "Username: " username
	read -s -p "Password: " password
	echo ''
	rm cookie &>/dev/null
	token=`curl -c cookie -s -o /dev/null 'https://www.plurk.com/login' \
		| grep -oh 'login_token" value=".*"\ \/>\ <input\ type="hidden"\ name="logintoken"\ value="1"\ \/>' \
		| sed -e 's/login_token"\ value="//g' -e 's/"\ \/>\ <input\ type="hidden"\ name="logintoken"\ value="1"\ \/>//g'`
	curl -L -c cookie -s -o /dev/null 'https://www.plurk.com/Users/login' --data "nick_name=$username&password=$password&login_token=$token&logintoken=1"
}

function username2id(){
	curl -s "https://www.plurk.com/$1" | grep -oh 'showFriends?user_id=.*&page=all' | sed -e 's/showFriends?user_id=//g' -e 's/&page=all//g'
}

function getuserdata(){
	echo "-----------$1-----------"
	curl -b cookie -s 'https://www.plurk.com/Users/getUserData' --data "page_uid=$1" | jq -r '"Fans: " + (.num_of_fans | tostring) + "\n" + "Friend: " + (.num_of_friends | tostring) + "\n" + "Mutual Friend: " + (.num_of_mutual_friends | tostring)'
	curl -b cookie -s 'https://www.plurk.com/Friends/getMyFriendsCompletion' -X POST | jq -r '.["'$1'"] | "Username: " + (.nick_name | tostring) + "\n" + "Nickname: " +  (.display_name | tostring) + "\n" + "Realname: " +  (.full_name | tostring) '
}

function get_friends_by_offset(){
	userid=$1
	offset=0
	while true
	do
			res=`curl -b cookie -s 'https://www.plurk.com/Friends/getFriendsByOffset' --data "offset=$offset&user_id=$userid"`
			[ "$res" == '[]' ] && return 0
			echo $res | sed 's/"date_of_birth":\ new Date(".\{1,30\}"),//g' | jq '.[].uid'
			offset=$(($offset + 10))
	done
}

function get_mutual_friends_by_offset(){
	userid=$1
	offset=0
	while true
	do
		res=`curl -b cookie -s 'https://www.plurk.com/Friends/getMutualFriendsByOffset' --data "offset=$offset&user_id=$userid"`
		[ "$res" == '[]' ] && return 0
		echo $res | sed 's/"date_of_birth":\ new Date(".\{1,30\}"),//g' | jq '.[].uid'
		offset=$(($offset + 10))
	done
}

function and_list(){
	#A跟B都有看到
	awk 'FNR==NR{ array[$0]; next} {if ( $1 in array ) print $1 ;next}' $1 $2
}

function subtract_list(){
	#A有看到B沒看到
	awk 'FNR==NR{ array[$0]; next} {if ( $1 in array ) next; print $1}' $2 $1
}

function clean_up(){
	rm tmp_final
	rm cookie
}


login
echo "Logging...."
c=1
total=`wc -l rule`
while read line
do
	echo "$c of $total:"
	rule=${line:0:1}
	username=${line:1:${#line}-1}
	echo "Fetch friends list of $username" && get_friends_by_offset `username2id $username` > tmp
	[ $c -eq 1 ] && mv tmp tmp_final
	[ $c -gt 1 ] && [ "$rule" == "+" ] && echo "$username can see the plurk" && and_list tmp_final tmp > tmp_tmp
	[ $c -gt 1 ] && [ "$rule" == "-" ] && echo "$username cannot see the plurk" && subtract_list tmp_final tmp > tmp_tmp
	[ $c -gt 1 ] && rm tmp_final tmp && mv tmp_tmp tmp_final
	c=$(($c + 1))
done < rule

echo -e "\n\nList possible person:\n"
while read line
do
	getuserdata $line
done < tmp_final

clean_up
