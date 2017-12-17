#!/bin/bash

trap "exit 1" TERM
export TOP_PID=$$

function stderr(){
	# For user messages.
	echo -e $1 >&2
}

function username2id(){
	# Convert the username (offically they called nickname) to userid.
	# The format for userid is \d+
	id=`curl -s "https://www.plurk.com/$1" | grep -oh 'showFriends?user_id=.*&page=all' | sed -e 's/showFriends?user_id=//g' -e 's/&page=all//g'`
	[ -z "$id" ] && stderr 'User not exist, Exiting...' && kill -s TERM $TOP_PID
	echo $id
}

function getuserdata(){
	echo "-----------$2-----------"
	curl -s 'https://www.plurk.com/Users/getUserData' --data "page_uid=$1" | jq -r '"Fans: " + (.num_of_fans | tostring) + "\n" + "Friend: " + (.num_of_friends | tostring)'
	curl -s "https://www.plurk.com/$2" | grep -oP 'var GLOBAL = \K.*' | sed 's/"date_of_birth":new Date(".\{1,30\}"),//g' | jq -r '"Full name: " + .page_user.full_name + "\n" + "Display name: " + .page_user.display_name + "\n" + "Default Lang: " + .page_user.default_lang'
	[ "$tf" == "y" ] && echo "Last Login (UTC): $3"
	[ "$tf" != "y" ] && echo "Last Login (UTC): "`curl -s "https://www.plurk.com/$username" | grep -oP 'last_visit = new Date\('"'"'\K.*'"(?='\.)"`
}

function get_friends_by_offset(){
	# Print the friend list (user ID) of a specific user ID to stdout.
	userid=$1
	stderr "Fetching Friends"
	stderr "- User id: $userid"
	friendcount=`get_friends_count $userid`
	offset=0
	while true
	do
		stderr "- Fetch $offset of $friendcount"
		res=`curl -s 'https://www.plurk.com/Friends/getFriendsByOffset' --data "offset=$offset&user_id=$userid"`
		[ "$res" == '[]' ] && return 0
		echo $res | sed 's/"date_of_birth":\ new Date(".\{1,30\}"),//g' | jq -r '.[] | if (.is_disabled == false) then [(.uid | tostring), .nick_name, (if (.timeline_privacy==0) then "y"else "n" end), .default_lang] | join(",") else empty end'
		offset=$(($offset + 10))
	done
}

function get_friends_count(){
	# Get friends count, but doesn't check the username, so be sure check the username existence before use.
	userid=$1
	echo `curl -s "https://www.plurk.com/Friends/showFriends?user_id=$userid&page=" | grep -oP "'friends',.+?,\s\K\d+"`
}

function get_following_by_offset(){
	# Print the friend list (user ID) of a specific user ID to stdout.
	userid=$1
	stderr "Fetching Following"
	stderr "- User id: $userid"
	offset=0
	while true
	do
		stderr "- Fetch $offset"
		res=`curl -s 'https://www.plurk.com/Friends/getFollowingByOffset' --data "offset=$offset&user_id=$userid"`
		[ "$res" == '[]' ] && return 0
		echo $res | sed 's/"date_of_birth":\ new Date(".\{1,30\}"),//g' | jq -r '.[] | if (.is_disabled == false) then [(.uid | tostring), .nick_name, (if (.timeline_privacy==0) then "y"else "n" end), .default_lang] | join(",") else empty end'
		offset=$(($offset + 10))
	done
}

function and_list(){
	# List $1 and list $2 both have the plurk.
	# A跟B都有看到
	awk 'FNR==NR{ array[$0]; next} {if ( $1 in array ) print $1 ;next}' $1 $2
}

function subtract_list(){
	# List $1 have the item, but list $2 doesn't.
	# A有看到B沒看到
	awk 'FNR==NR{ array[$0]; next} {if ( $1 in array ) next; print $1}' $2 $1
}

function clean_up(){
	rm -f tmp
	rm -f tmp_final
}

clean_up
c=1
total=`wc -l rule`
while read line
do
	stderr "$c of $total:"
	rule=${line:0:1}
	username=${line:1:${#line}-1}
	userid=`username2id $username`
	stderr "Fetch friends list of $username" && get_friends_by_offset $userid > tmp
	stderr "Fetch following list of $username" && get_following_by_offset $userid >> tmp
	[ $c -eq 1 ] && mv tmp tmp_final
	[ "$rule" == "+" ] && stderr "$username can see the plurk" && and_list tmp_final tmp > tmp_tmp
	[ "$rule" == "-" ] && stderr "$username cannot see the plurk" && subtract_list tmp_final tmp > tmp_tmp
	[ $c -gt 1 ] && rm tmp_final tmp && mv tmp_tmp tmp_final
	c=$(($c + 1))
done < rule

stderr "Is the anonymous plurk replurkable? (Y/n)"
read rpa
rpa=`echo "$rpa" | tr '[:upper:]' '[:lower:]'`
[ "$rpa" != "n" ] && rpa='y'
awk -F, '{if($3=="'$rpa'"){print};next}' tmp_final > tmp
mv tmp tmp_final

# The qualifier can be fetched by self-xss the following code on any user page
# out = ""
# for (a in window.LANG_QUAL){
# 	out += a + "," + window.LANG_QUAL[a].whispers + "\n";
# }
# console.log(out);
stderr "\n[Experiment function]"
stderr "It might be unaccuracy due to the different language setting on mobile device or changing the default language."
stderr "Enable Language Filter? (y/N)"
read lf
lf=`echo "$lf" | tr '[:upper:]' '[:lower:]'`
if [ "$lf" == "y" ]
then
	c=0
	mv tmp_final tmp
	stderr "What is the qualifier?"
	read qualifier
	while read lang
	do
		c=1
		awk -F, '{if($4=="'$lang'"){print}}' tmp >> tmp_final
	done < <(awk -F, '{if($2=="'$qualifier'"){print $1}}' qualifier)
	[ $c -eq 0 ] && stderr "String not found in the language pack, disabling language filter..." && mv tmp tmp_final
	[ $c -eq 1 ] && rm tmp
fi

stderr "\n[Experiment function]"
stderr "It might be unaccuracy due to non-refersh time of last login."
stderr "Enable Time Filter? (Y/n)"
read tf
tf=`echo "$tf" | tr '[:upper:]' '[:lower:]'`
[ "$tf" != "n" ] && tf='y'
if [ "$tf" == "y" ]
then
	# I don't want to deal with your wrong format lol
	# so if you entering wrong fmt is your problem
	stderr "Using format that your 'date' command can accept"
	stderr "Recommanded format: yyyy-mm-dd hh:mm"
	stderr "Enter the time of the plurk (Your timezone):"
	read t
	TZ=Asia/Taipei # Your Timezone, change it
	t=`date -d "TZ=\"$TZ\" $t" +%s`
	if [ -z "$t" ]
	then
		stderr "Wrong format, disabling time filter"
	else
		mv tmp_final tmp
		stderr "Running...\nPlease wait"
		while read line
		do
			username=`echo $line | awk -F ',' '{print $2}'`
			ot=`curl -s "https://www.plurk.com/$username" | grep -oP 'last_visit = new Date\('"'"'\K.*'"(?='\.)"` # Fetch last login time
			d=`date -d "TZ=\"UTC-8\" $ot" "+%s"` # UTC-8 mean the orginal time minor 8 hr for the calibration of plurk last login refeash time
			[ $d -ge $t ] && echo "$line,$ot" >> tmp_final
		done < tmp
		rm tmp
	fi
fi


stderr "\nPossible outcome: `wc -l tmp_final | awk '{print $1}'`\nList possible person:\n"
while read line
do
	userid=`echo $line | awk -F ',' '{print $1}'`
	username=`echo $line | awk -F ',' '{print $2}'`
	last_login=`echo $line | awk -F ',' '{print $5}'`

	p=0
	while read provider
	do
		[ "${provider:1:${#provider}-1}" == "$username" ] && p=1
	done < rule
	[ $p -eq 0 ] && getuserdata $userid $username "$last_login" $tf
done < tmp_final

clean_up
