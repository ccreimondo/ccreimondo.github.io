# Tips, Tricks and Shortcuts of Sublime Text 3

## Create A Project
为源码目录创建一个project，最基本的配置如下。

```json
{
	"folders": [
		{
			"path": "."
		}
	],
	"settings": {
		"tab_size": 8,
		"translate_tabs_to_spaces": false,
                "rulers": [80]
	}
}
```


## Some Plugins

- Vintageous  
- C Improved
- GAS-x86 (or x64) highlighting scheme


## Search

- shift+cammand+R: global search for characters 
- command+p: global search for files
- command+p & #: local search for characters
- command+P & @: local search for function