//
//  ${TM_NEW_FILE_BASENAME}
//
//  Created by ${TM_USERNAME} on ${TM_DATE}.
//  Copyright (c) ${TM_YEAR} ${TM_ORGANIZATION_NAME}. All rights reserved.
//

package ${TM_AS3_NAMESPACE}{
	/**
	 * ${TM_NEW_FILE_BASENAME}
	 * ${TM_NEW_FILE_BASENAME} description.
	 *
	 * @author ${TM_USERNAME}
	 * @langversion ActionScript 3.0
	 * @playerversion Flash 9
	 */
	public class ${TM_NEW_FILE_BASENAME} {
		private static var _instance:${TM_NEW_FILE_BASENAME};
		
		public function ${TM_NEW_FILE_BASENAME}(singleton_enforcer:${TM_NEW_FILE_BASENAME}SingletonEnforcer) {}
		
		public static function instance():${TM_NEW_FILE_BASENAME} {
			if (_instance == null)
				_instance = new ${TM_NEW_FILE_BASENAME}(new ${TM_NEW_FILE_BASENAME}SingletonEnforcer());
			
			return _instance;
		}$0
	}
}
internal class ${TM_NEW_FILE_BASENAME}SingletonEnforcer {}