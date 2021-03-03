<?php
/**
 * Created by PhpStorm.
 * Date: 18.05.20
 * Time: 18:20
 * put in bitrix/php_interface/include/classes/imageOptim/
 */
namespace imageOptim;

class optimWebp
{
        private static $webpExtension = [
                'jpeg','jpg','png'
        ];

        private static function optimization($file, $extension)
        {
                if(in_array($extension, self::$webpExtension))
                        shell_exec('cwebp ' . $file . ' -o ' . $file . '.webp');
        }

        public static function run()
        {
                self::findAll(__DIR__ . "/../../../../templates/domain.tld/img");
                self::findAll(__DIR__ . "/../../../../../upload/fileman");
                self::findAll(__DIR__ . "/../../../../../upload/main");
                self::findAll(__DIR__ . "/../../../../../upload/medialibrary");
                self::findAll(__DIR__ . "/../../../../../upload/iblock");
                self::findAll(__DIR__ . "/../../../../../upload/resize_cache");
                self::findAll(__DIR__ . "/../../../../../upload/uf");
        }

        private static function findAll($path)
        {
                $it = new \RecursiveDirectoryIterator($path);
                $display = [ 'jpeg', 'jpg', 'png' ];
                $count = 0;
                foreach(new \RecursiveIteratorIterator($it) as $file)
                {
                        $extension = strtolower(array_pop(explode('.', $file)));
                        if (in_array($extension, $display) && !file_exists($file . '.webp'))
                        {
                                self::optimization($file, $extension);
                                $count++;
                        }
                }
                var_dump($count);
        }
}

optimWebp::run();
