package mobile.backend;

import haxe.crypto.Md5;
import haxe.io.Path;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class AssetsUtil {
	static final path:String = lime.system.System.applicationStorageDirectory;

	public static function getPathVideo(id:String, ?ext:String = ""):String {
		#if mobile
		var fileName = Md5.encode(id) + ext;
		var fullPath = Path.join([path, fileName]);

		if (!FileSystem.exists(fullPath)) {
			var fileBytes = Assets.getBytes(id);
			if (fileBytes != null) {
				File.saveBytes(fullPath, fileBytes);
			}
		}

		return fullPath;
		#else
		#if sys
		return Path.join([Sys.getCwd(), id]);
		#else
		return id;
		#end
		#end
	}
	
	public static function readDirectoryFilter(path:String):Array<String> {
		return Assets.list().filter(directory -> directory.contains(path));
	}
}