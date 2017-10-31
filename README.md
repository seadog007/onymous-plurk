# 這是什麼?

onymous-plurk是一款可以自動比對好友列表來找到偷偷說發文者的工具

# 需求

* jq
  * `sudo apt-get install jq`
* awk (GNU)
* curl

# 使用說明

1. 根據你所問到朋友的回應來更改 `rule` 的內容  
  i. 第一行保持 `+自己的ID` (自己可以看到該偷偷說)
  ii. 假設您的朋友A說**可以**看的到該偷偷說，則加入一行 `+A的ID`  
  iii. 假設您的朋友B說**不能**看的到該偷偷說，則加入一行 `-B的ID`  
  iv. 範例：  
    ```
    +自己的ID
    +A的ID
    -B的ID
    ```

2. 執行 `./run.sh`

--------------

# What is this?

onymous-plurk is a tool for automatically find the plurker who send an anonymous plurk by cross-matching friend list.

# Requirements

* jq
  * `sudo apt-get install jq`
* awk (GNU)
* curl

# Usage

1. According to respondes of your friends, Change the content of `rule`  
  i. Leave the first line with `+your_own_id` (Which means you can see the anonymous plurk)
  ii. If your friend A **can** see the plurk, then add a new line with content `+ID_of_A`  
  iii.  If your friend A **cannot** see the plurk,then add a new line with content `-ID_of_B`  
  iv. Example：  
    ```
    +your_own_id
    +ID_of_A
    -ID_of_B
    ```

2. Run the script `./run.sh`
