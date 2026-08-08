minigame <- Ware_MinigameData
({
	name            = "Say the Word"
	author          = ["Gemidyne", "ficool2"]
	description     = "Say the word below!"
	duration        = 4.0
	end_delay       = 0.5
	music           = "getready"
	custom_overlay2 = "../chalkboard"
	suicide_on_end  = true
})

words <-
[
	"헤비"
	"스카운"
	"자라테"
	"렌치"
	"스파이"
	"솔저"
	"메딕"
	"스나이퍼"
	"사샤"
	"엔지"
	"색스턴"
	"샌드맨"
	"파이로"
	"데모맨"
	"엔지니어"
	"박쥐"
	"곰"
	"주먹"
	"하양"
	"와리오"
	"벨브"
	"검정"
	"노랑"
	"연두"
	"파랑"
	"플라위" // :)
	"만코"
	"센트리"
	"로켓"
	"점착"
	"우버"
	"시계"
	"샌드비치"
	"샌드위치"
	"봉크"
	"헤일"
	"상자"
	"키"
	"도발"
	"스파이크랩"
	"크리티컬"
	"수레밀기"
	"거점점령"
	"아레나"
	"코믹스"
	"범상치않은"
	"이상한"
	"게이븐"
	"스팀"
	"폐기금속"
	"광택"
	"거점"
	"탱크"
	"세퍼"
	"콩가"
	"예티"
	"서류가방"
	"계약"
	"호주인"
	"이어버드"
	"변장"
	"에임봇"
	"2포트"
	"더스트보울"
	"그래내리"
	"그래벌핏"
	"하이드로"
	"웰"
	"크람푸스"
	"플로지"
	"프롭헌트"
	"스매쉬"
	"와리오웨어"
	"명일방주"
	"개구리"
	"애옹"
	"고양이"
	"샌즈"
	"쿠키"
	"햇터틀"
	"브이스크립트"
	"도토리"
	"폰"
	"점검"
	"충돌"
	"라이덴"
	"프리키"
	"바나나"
	"꽥"
	"왕중왕"
	"붐비노미콘"
	
	// these are evil but rare
	"트랄랄레로트랄랄라"
	"봄바르디로크로코딜로"
	"퉁퉁퉁퉁퉁퉁퉁퉁퉁사후르"
	"리릴리라릴라"
	"브르르브르르파타핌"

	
	// I'm so sorry
	"트리파트로파트랄랄라리릴리릴라퉁퉁사후르보네카퉁퉁트랄랄레로트리피트로파크로코디나"
]

first <- true
word <- null

function OnPick()
{
	return !Ware_IsSpecialRoundSet("hale") // disabled due to text channel conflict
}

function OnStart()
{
	word = RandomElement(words)
	// these spaces are to prevent localization
	Ware_ShowMinigameText(null, format(" %s ", word))
	word = word.tolower()
}

function OnPlayerSay(player, text)
{	
	if (text.tolower() == word)
	{
		if (player.IsAlive())
		{
			Ware_PassPlayer(player, true)
			if (first)
			{
				Ware_ChatPrint(null, "{player} {color}said the word first!", player, TF_COLOR_DEFAULT)
				Ware_GiveBonusPoints(player)
				first = false
			}
		}
		return false
	}
	else
	{
		if (Ware_IsPlayerPassed(player) || !player.IsAlive())
			return
		
		Ware_SuicidePlayer(player)
	}
}