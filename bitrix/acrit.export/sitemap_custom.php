<?php
// подключение служебной части пролога
require($_SERVER["DOCUMENT_ROOT"]."/bitrix/modules/main/include/prolog_before.php");

use \Bitrix\Main\Loader;
\Bitrix\Main\Loader::IncludeModule('seo');

use Bitrix\Main\Entity;
use Bitrix\Main\Text\Converter;
use Bitrix\Main\IO\File;
use Bitrix\Main\IO\Path;
use Bitrix\Seo\SitemapFile;
use Bitrix\Seo\RobotsFile;

class SitemapFileCustom extends SitemapFile{
	
	const ENTRY_TPL = '<url><loc>%s</loc><lastmod>%s</lastmod><changefreq>weekly</changefreq><priority>0.5</priority></url>';
	const ENTRY_TPL_SEARCH = '<url><loc>%s</loc>';
	const PROTO_HOST = 'http://site.loc';
	
	public function __construct($fileName, $settings)
	{
		parent::__construct($fileName, $settings);
	}
	
	
	/**
	 * Adds new entry to the current sitemap file
	 *
	 * Entry array keys
	 * XML_LOC - loc field value
	 * XML_LASTMOD - lastmod field value
	 *
	 * @param array $entry Entry array.
	 *
	 * @return void
	 */
	public function addEntry($entry)
	{
		$arDisallowRules = $this->getRobotsRulesList();
		$entryMdf = $this->replaceProtoHost(self::PROTO_HOST, $entry['XML_LOC']);
		
		if(!in_array($entryMdf, $arDisallowRules)){		
			if ($this->isSplitNeeded())
			{
				$this->split();
				$this->addEntry($entry);
			}
			else
			{
				if (!$this->partChanged)
				{
					$this->addHeader();
				}

				$this->putContents(
					sprintf(
						self::ENTRY_TPL,
						Converter::getXmlConverter()->encode($entry['XML_LOC']),
						Converter::getXmlConverter()->encode($entry['XML_LASTMOD'])
					), self::APPEND
				);
			}
		}
	}
	
	/**
	 * Adds new IBlock entry to the current sitemap
	 *
	 * @param string $url IBlock entry URL.
	 * @param string $modifiedDate IBlock entry modify timestamp.
	 *
	 * @return void
	 */
	public function addIBlockEntry($url, $modifiedDate)
	{
        $e = [];

		$this->addEntry(array(
			'XML_LOC' => $this->settings['PROTOCOL'].'://'.\CBXPunycode::toASCII($this->settings['DOMAIN'], $e).$url,
			'XML_LASTMOD' => date('c', $modifiedDate - \CTimeZone::getOffset()),
		));
	}
	
	/**
	 * Appends new entry to the existing and finished sitemap file
	 *
	 * Entry array keys
	 * XML_LOC - loc field value
	 * XML_LASTMOD - lastmod field value
	 *
	 * @param array $entry Entry array.
	 *
	 * @return void
	 */
	public function appendEntry($entry)
	{
		if($this->isSplitNeeded())
		{
			$this->split();
			$this->appendEntry($entry);
		}
		else
		{
			if(!$this->partChanged)
			{
				$this->addHeader();
				$offset = $this->getSize();
			}
			else
			{
				$offset = $this->getSize()-strlen(self::FILE_FOOTER);
			}

			$fd = $this->open('r+');

			fseek($fd, $offset);
			fwrite($fd, sprintf(
				self::ENTRY_TPL,
				Converter::getXmlConverter()->encode($entry['XML_LOC']),
				Converter::getXmlConverter()->encode($entry['XML_LASTMOD'])
			).self::FILE_FOOTER);
			fclose($fd);
			
			$this->footerClosed = true;
		}
	}
	
	/**
	 * Получаем список url из robots.txt по типу
	 * @param string $type = Disallow / Allow
	 * 
	 * @return array
	*/
	
	protected function getRobotsRulesList($type='Disallow'){
		$robotsFile = new RobotsFile($this->settings['SITE_ID']);
		$allRulesArr = $robotsFile->getRules($type);
		$arRulesUrls = Array();
		
		if(count($allRulesArr) > 0){
			foreach($allRulesArr as $k=>$al){
				$arRulesUrls[] = $al[1];
			}
		}
		
		return $arRulesUrls;		
	}
	
	
	/**
	 * Обертка над функцией str_replace
	 * Удаляет из url протокол и хост
	 *
	 */
	protected function replaceProtoHost($search, $subject){		
		return str_replace($search, '', $subject);
	}
	
}

class SitemapRuntimeCustom extends SitemapFileCustom{
	const PROGRESS_WIDTH = 500;
	
	protected $PID = 0;
	private $originalFile = NULL;
	
	public function __construct($PID, $fileName, $arSettings)
	{
		$this->PID = $PID;
		
		if ($this->partFile == '')
		{
			$this->partFile = $fileName;
		}

//		normalize slashes
		$fileName = Path::normalize($fileName);
//		divide directory and path tp correctly add prefix
		$lastSlashPosition = strrpos($fileName, "/");
		$fileDirectory = '';
		if ($lastSlashPosition !== false)
		{
			$fileDirectory = substr($fileName, 0, $lastSlashPosition + 1);
			$fileName = substr($fileName, $lastSlashPosition + 1);
		}
		
		parent::__construct($fileDirectory . $this->getPrefix() . $fileName, $arSettings);
	}
	
	/**
	 * Recreate file with same settings to new part
	 *
	 * @param string $fileName
	 */
	protected function reInit($fileName)
	{
		$this->__construct($this->PID, $fileName, $this->settings);
	}
	
	public function putSitemapContent(SitemapFile $sitemapFile)
	{
//		always write in new empty file - this is necessary
		if ($this->isExists())
			$this->delete();
		
		if ($sitemapFile->isExists())
		{
			$this->putContents($sitemapFile->getContents());
			$this->partChanged = true;
			$this->footerClosed = true;
		}
		else
		{
			$this->addHeader();
		}
	}
	
	
	public function setOriginalFile(SitemapFile $sitemapFile)
	{
		if (isset($sitemapFile))
			$this->originalFile = $sitemapFile;
	}
	
	/**
	 * Overwrite parent method to creating temp-files and correctly work with multipart
	 * Appends new IBlock entry to the existing finished sitemap
	 *
	 * @param string $url IBlock entry URL.
	 * @param string $modifiedDate IBlock entry modify timestamp.
	 *
	 * @return void
	 */
	public function appendIBlockEntry($url, $modifiedDate)
	{
//		if not set original file - to use as common sitemap file
		if(!$this->originalFile)
		{
			parent::appendIBlockEntry($url, $modifiedDate);
			return;
		}
		
		if ($this->originalFile->isExists())
		{
//			move sitemapfile to end, find name of last part
			while ($this->originalFile->isSplitNeeded())
			{
				$filename = $this->originalFile->split();
			}

//			if part was changed - create new runtime part file
			if (isset($filename) && $filename)
				$this->reInit($filename);
			
			$this->putSitemapContent($this->originalFile);
			$this->appendEntry(array(
				'XML_LOC' => $this->settings['PROTOCOL'] . '://' . \CBXPunycode::toASCII($this->settings['DOMAIN'], $e = NULL) . $url,
				'XML_LASTMOD' => date('c', $modifiedDate - \CTimeZone::getOffset()),
			));
		}
		else
		{
			$this->addHeader();
			$this->addIBlockEntry($url, $modifiedDate);
			$this->addFooter();
		}
	}
	
	/**
	 * Rename runtime file to original name. If runtime have part - rename them all
	 */
	public function finish()
	{
		foreach ($this->partList as $key => $partName)
		{			
			$f = new File(Path::combine($this->getDirectoryName(), $partName));
			$f->rename(str_replace($this->getPrefix(), '', $f->getPath()));
			$this->partList[$key] = $f->getName();
		}
		
		if ($this->isCurrentPartNotEmpty())
		{
			if (!$this->footerClosed)
				$this->addFooter();
			$this->rename(str_replace($this->getPrefix(), '', $this->getPath()));
		}
	}
	
	protected function getPrefix()
	{
		return '~' . $this->PID;
	}
	
	public static function showProgress($text, $title, $v)
	{
		$v = $v >= 0 ? $v : 0;
		
		if ($v < 100)
		{
			$msg = new \CAdminMessage(array(
				"TYPE" => "PROGRESS",
				"HTML" => true,
				"MESSAGE" => $title,
				"DETAILS" => "#PROGRESS_BAR#<div style=\"width: " . self::PROGRESS_WIDTH . "px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding-top: 20px;\">" . Converter::getHtmlConverter()->encode($text) . "</div>",
				"PROGRESS_TOTAL" => 100,
				"PROGRESS_VALUE" => $v,
				"PROGRESS_TEMPLATE" => '#PROGRESS_PERCENT#',
				"PROGRESS_WIDTH" => self::PROGRESS_WIDTH,
			));
		}
		else
		{
			$msg = new \CAdminMessage(array(
				"TYPE" => "OK",
				"MESSAGE" => $title,
				"DETAILS" => $text,
			));
		}
		
		return $msg->show();
	}	
}