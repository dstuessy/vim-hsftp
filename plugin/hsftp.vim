" Title: hsftp
" Description: Upload and download files through sftp
" Usage: :Hupload and :Hdownload
"        By default mapped to
"        <leader>hsd (hsftp download) and
"        <leader>hsu (hsftp upload)
"        See README for more
" Github: https://github.com/hesselbom/vim-hsftp
" Author: Viktor Hesselbom (hesselbom.net)
" License: MIT


" 
" Get dictionary with config values from
" the closest config file in a parent directory.
" Does not traverse siblings!
" 
" @return {dictionary} A dictionary holding all found config settings
function! h:GetConf()

	let conf = {}
	let l:currentpath = expand('%:p:h')
	let l:foundconfig = s:findConfig(l:currentpath)

	if strlen(l:foundconfig) > 0

		let options = readfile(l:foundconfig)

		function! l:toConf(acc, option) 

			let l:option = split(a:option, '\s\+')
			let l:name = l:option[0]
			let l:val = join(l:option[1:], ' ')

			let a:acc[l:name] = l:val

			return a:acc
		endfunction

		let conf = s:reduce(function("l:toConf"), {}, options)

		let conf['local'] = fnamemodify(l:foundconfig, ':h:p') . '/'
		let conf['projectpath'] = s:cleanPath('/' . join(split(l:foundconfig, '/')[:-2], '/'))
		let conf['localpath'] = expand('%:p')
		let conf['remotepath'] = conf['remote'] . conf['localpath'][strlen(conf['local']):]
	endif

	return conf
endfunction

"
" Find the config path
"
" @param {string} currentpath The starting path in which to find config file
" @return {string|false} String of found config path, or false if not found
function! s:findConfig(currentpath)

	let l:configname = '.hsftp'
	let l:path = a:currentpath
	let l:configpath = l:path . '/' . l:configname

	" look for the config file in each parent directory of the current path
	while !filereadable(l:configpath) && strlen(l:path) > 1
		let l:path = s:cleanPath('/' . join(split(l:path, '/')[:-2], '/'))
		let l:configpath = s:cleanPath(l:path . '/' . l:configname)
	endwhile

	" return false if config file is not readable
	if (!filereadable(l:configpath))
		return ""
	endif

	return l:configpath
endfunction

"
" Removes repeating forward slashes '/'
"
" @param {string} path
" @return {string} Clean path
function! s:cleanPath(path)
	return substitute(substitute(a:path, '/\+', '/', 'g'), '/\$', '', '')
endfunction

"
" A traditional reduce function!
"
" @param {function} fn The function with which to reduce list entries.
" @param {mixed} start The start value for the reduction
" @param {list} list The list to reduce (immutably).
" @return {mixed} The end result of the reduction.
function! s:reduce(fn, start, list)

	let l:newlist = deepcopy(a:list)
	let l:acc = deepcopy(a:start)

	for i in l:newlist
		let l:acc = a:fn(l:acc, i)
	endfor

	return l:acc
endfunction

function! h:DownloadFile()

	let conf = h:GetConf()

	if has_key(conf, 'host')

		let action = printf('get %s %s', conf['remotepath'], conf['localpath'])
		let cmd = printf('expect -c "set timeout 5; spawn sftp -P %s %s@%s; expect \"*assword:\"; send %s\r; expect \"sftp>\"; send \"%s\r\"; expect -re \"100%\"; send \"exit\r\";"', conf['port'], conf['user'], conf['host'], conf['pass'], action)


		if conf['confirm_download'] == 1
			let choice = confirm('Download file?', "&Yes\n&No", 2)
			if choice != 1
				echo 'Canceled.'
				return
			endif
		endif

		execute '!' . cmd
	else
		echo 'Could not find .hsftp config file'
	endif
endfunction

function! h:UploadFile()

	let conf = h:GetConf()

	if has_key(conf, 'host')

		let action = printf('put %s %s', conf['localpath'], conf['remotepath'])
		let cmd = printf('expect -c "set timeout 5; spawn sftp -P %s %s@%s; expect \"*assword:\"; send %s\r; expect \"sftp>\"; send \"%s\r\"; expect -re \"100%\"; send \"exit\r\";"', conf['port'], conf['user'], conf['host'], conf['pass'], action)

		if conf['confirm_upload'] == 1
			let choice = confirm('Upload file?', "&Yes\n&No", 2)
			if choice != 1
				echo 'Canceled.'
				return
			endif
		endif

		execute '!' . cmd
	else
		echo 'Could not find .hsftp config file'
	endif
endfunction

function! h:UploadFolder()

	let conf = h:GetConf()

	" execute "! echo " . file
	" let conf['localpath'] = expand('%:p')
	let action = "send pwd\r;"

	if has_key(conf, 'host')

		for file in split(glob('%:p:h/*'), '\n')

			let conf['localpath'] = file
			let conf['remotepath'] = conf['remote'] . conf['localpath'][strlen(conf['local']):]

			if conf['confirm_upload'] == 1
				let choice = confirm('Upload file?', "&Yes\n&No", 2)
				if choice != 1
					echo 'Canceled.'
					return
				endif
			endif

			let action = action . printf('expect \"sftp>\"; send \"put %s %s\r\";', conf['localpath'], conf['remotepath'])
		endfor

		" let cmd = printf('expect -c "set timeout 5; spawn sftp -P %s %s@%s; expect \"*assword:\"; send %s\r; expect \"sftp>\"; send \"%s\r\"; expect -re \"100%\"; send \"exit\r\";"', conf['port'], conf['user'], conf['host'], conf['pass'], action)

		let cmd = printf('expect -c "set timeout 5; spawn sftp -P %s %s@%s; expect \"*assword:\"; send %s\r; %s expect -re \"100%\"; send \"exit\r\";"', conf['port'], conf['user'], conf['host'], conf['pass'], action)

		execute '!' . cmd
	else
		echo 'Could not find .hsftp config file'
	endif

endfunction

command! Hdownload call h:DownloadFile()
command! Hupload call h:UploadFile()
command! Hupdir  call h:UploadFolder()

nmap <leader>hsd :Hdownload<Esc>
nmap <leader>hsu :Hupload<Esc>
nmap <leader>hsf :Hupdir<Esc>
