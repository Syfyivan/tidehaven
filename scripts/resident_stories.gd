extends RefCounted
## Personal conversations, separate from repeatable errands and the shared island story.
## The host validates proximity and language access before calling this module.
const Inventory = preload("res://scripts/inventory.gd")
const MONEY_LIMIT := 1000000000
const ARCS := {
	"lu_zhou": {"name":"陆舟", "title":"绳结另一端", "coins":24, "steps":[
		{"at":"lu_zhou", "text":"那场大浪里，我把绳子扔偏了。人救上来了，可我一听见风声，还是会数一遍救生绳。周潮当时也在船上，我一直没敢问他。", "replies":[{"label":"我去听听他的记忆。", "answer":"别替我说好话。我想知道，他当时到底看见了什么。"}, {"label":"先问问他现在怎么出海。", "answer":"也好。也许我该看看，大家是怎么继续过日子的。"}]},
		{"at":"zhou_chao", "text":"陆舟只记得第一回没扔准。我记得他第二回拴住船尾，手掌磨破了也没松。准备周全是好事，可他不必一个人守着整片海。", "replies":[{"label":"把第二次也讲给他听。", "answer":"这话早该说了。你回去告诉他，我记得那个没松手的人。"}, {"label":"他需要有人替一会儿班。", "answer":"说得对。下回我和他谈排班，不只说一句别怕。"}]},
		{"at":"lu_zhou", "delay":1, "cost":{"rope":2}, "text":"昨晚我想起了那次救援的后半段。新绳子带来了吗？这两根留作练习。我还会害怕，只是不想再把害怕藏起来。", "replies":[{"label":"就从和同伴练习开始。", "answer":"好。以后你问起那场风浪，我会先说：我们把人带回来了。我会记得你让我重新相信同伴。"}, {"label":"累了也可以把值班交出去。", "answer":"嗯。我会先学着开口说需要休息。你让我明白，救援员也可以被人照顾。"}]}
	]},
	"mu_tong": {"name":"沐桐", "title":"没有开花的那页", "coins":20, "steps":[
		{"at":"mu_tong", "text":"我画了一本植物册，偏偏有一页怎么也画不好：被风吹倒的幼苗。城里的老师说，这样的画没人想看。你也这么觉得吗？", "replies":[{"label":"我想看它后来怎么样。", "answer":"那我先别撕。这株苗是田青种的，你能替我问问吗？"}, {"label":"倒下的样子也值得留下。", "answer":"你这么说，我就舍不得丢了。田青见过那天的风，去听听她怎么讲吧。"}]},
		{"at":"tian_qing", "text":"那株苗后来没活。我把它翻进土里，旁边留下来的倒长得不错。画画不用替田地遮丑，没收成的季节也是我们过的日子。", "replies":[{"label":"把这段经过写在画旁边。", "answer":"写吧。让人知道，种地不是每一回都会赢。"}, {"label":"画下它身边活下来的苗。", "answer":"这也好。别把一小片田画成孤零零的一株。"}]},
		{"at":"mu_tong", "delay":1, "text":"空白那页留到了今天。我不想把它画成励志故事，也不想假装什么都没发生。你愿意帮我给这页定个名字吗？", "replies":[{"label":"《风吹过的那天》。", "answer":"就叫这个。册子里会留下风留下的痕迹，也留下你肯认真看这一页的事。"}, {"label":"《旁边的新芽》。", "answer":"好，镜头往旁边挪一点。这页会记着同一块土里没能长大的和还在生长的生命。"}]}
	]},
	"gu_xing": {"name":"顾星", "title":"慢半拍的潮钟", "coins":24, "steps":[
		{"at":"gu_xing", "text":"这只旧潮钟一到外海就慢半拍。我已经调了三次，还不敢让人看记录。严砧说齿轮没问题，我却总觉得是自己算错了。", "replies":[{"label":"去听听修齿轮的人怎么说。", "answer":"好。请他直说，我这回不抢着解释。"}, {"label":"先把错开的记录留下。", "answer":"我差点把那几页撕了。严砧那儿也有修理记录，帮我对一对吧。"}]},
		{"at":"yan_zhen", "cost":{"scrap":3}, "text":"这几块废金属正好做试片。顾星拿港湾的潮表算外海，仪器当然对不上。让他把误差记下来，别每次都把指针拧回希望的地方。", "replies":[{"label":"请他把误差也当观察。", "answer":"对。肯承认不知道，才知道下一步该量什么。"}, {"label":"先做好港湾这一张潮表。", "answer":"也踏实。工具不必第一天就能回答整片海的问题。"}]},
		{"at":"gu_xing", "delay":1, "text":"我把旧记录摊开看了一夜。原来有些误差每次都出现，不是耻辱，是线索。我想给笔记第一页换一句话。", "replies":[{"label":"把不确定的也记下来。", "answer":"写好了：不知道的地方，留空继续看。以后谈起这只潮钟，我会记得你劝我保留误差。"}, {"label":"先把脚边的潮水看懂。", "answer":"那就从港湾开始，一页一页往外走。你让我不再急着用一只钟证明自己。"}]}
	]},
	"xu_mian": {"name":"许棉", "title":"不是样衣的颜色", "coins":20, "steps":[
		{"at":"xu_mian", "text":"这几件衣服针脚没问题，可摆在一起像是在等别人点头。我以前只照样衣做，轮到自己配色就不敢了。林穗说柜台边可以留一小角给我。", "replies":[{"label":"问问她喜欢你哪一件。", "answer":"好，但这回请她别只说都好看。"}, {"label":"问问她每天真正穿什么。", "answer":"这倒比问流不流行实在。你去听听，我把布摊开。"}]},
		{"at":"lin_sui", "text":"我最喜欢许棉给围裙补的那块蓝布。不是因为它贵，是她记得我总把右边口袋磨破。衣服要有人在里面过日子。", "replies":[{"label":"把那个口袋的故事告诉她。", "answer":"告诉她吧。那处补丁比整排样衣更像她。"}, {"label":"让她先做自己愿意穿的。", "answer":"好。她不必先得到全镇同意，才敢挑一种颜色。"}]},
		{"at":"xu_mian", "cost":{"fiber":4}, "text":"这些纤维够试几种针法了。我想明白了，先缝一件自己会反复穿的，再慢慢找自己的样子。你觉得该把什么留在这次练习里？", "replies":[{"label":"留下方便生活的小细节。", "answer":"那就从耐磨的口袋开始。这一回我记住的不是标准答案，是你替我留意穿衣服的人。"}, {"label":"留下你最喜欢的配色。", "answer":"我选海水退下去时那一点蓝绿。以后我再犹豫，就想起你说过：喜欢也能成为理由。"}]}
	]},
	"xu_an": {"name":"许岸", "title":"抽屉里的退租信", "coins":22, "steps":[
		{"at":"xu_an", "text":"荒院以前的住户留过一封退租信。我一直压在抽屉最下面，怕读完就得承认，这座镇子也会让人失望。陆遥送过他最后一段路。", "replies":[{"label":"先听听离开的人说了什么。", "answer":"嗯。别急着替镇子辩解，替我好好听。"}, {"label":"想知道他还惦记什么。", "answer":"我总盯着失去的，倒忘了问这一句。去找陆遥聊聊吧。"}]},
		{"at":"lu_yao", "text":"他没怪镇长。他说院子太大，一个人忙不过来，最后连出门聊天都觉得耽误活。他临走时最舍不得的，是澡堂里那一壶茶。", "replies":[{"label":"镇长需要听见真实的困难。", "answer":"请告诉他吧。不是每个离开的人都等着一句挽留。"}, {"label":"也告诉他，那壶茶没有白备。", "answer":"好。他们都记得彼此，只是从来没说出来。"}]},
		{"at":"xu_an", "delay":1, "text":"我读完了信，没有想象中那么可怕。以后再把钥匙交给谁，我想少讲一点远景，多问一句他们现在过得怎样。", "replies":[{"label":"先问今天缺什么。", "answer":"我会记住。你让我学着听眼前的生活，而不是急着把每个人写进计划。"}, {"label":"也允许他们选择离开。", "answer":"这句最难，但你说得对。能安心回来，也能好好告别，才是我希望的镇子。"}]}
	]},
	"he_mu": {"name":"贺木", "title":"父亲留下的尺", "coins":22, "steps":[
		{"at":"he_mu", "text":"这把木尺是父亲留下的，边角磨得看不清。我一直照着他做东西，连不同意的时候也不敢改。严砧年轻时跟他搭过工棚。", "replies":[{"label":"听听他年轻时怎么做事。", "answer":"也好。我记住的只有后来那副严肃样子。"}, {"label":"问问他有没有做错过。", "answer":"哈，我还真没问过。严砧应该不会替他藏着。"}]},
		{"at":"yan_zhen", "text":"你父亲？他做第一扇门时把铰链装反了。后来他最爱说，尺子管长短，不管你想做什么。贺木只记住了前半句。", "replies":[{"label":"把整句话带回去。", "answer":"去吧。我听见老伙计说这句时，他还笑着呢。"}, {"label":"把那扇反门也带进故事。", "answer":"该说。他会想听见父亲也是慢慢学会的。"}]},
		{"at":"he_mu", "cost":{"wood":3}, "text":"木板我收到了，正好试一段新榫。旧尺我还留着，只是这次想按自己的想法下锯。你说该怎么记这次练习？", "replies":[{"label":"把你的刻度添在旁边。", "answer":"好。旧痕迹不擦掉，新刻度也不藏着。这把尺往后会同时记着两代人的手。"}, {"label":"旧尺留作念想，另做一把。", "answer":"嗯。想念父亲，不必每次都请求他的许可。你让我终于敢把名字刻在自己的尺上。"}]}
	]},
	"yan_zhen": {"name":"严砧", "title":"炉边的半成品", "coins":24, "steps":[
		{"at":"yan_zhen", "text":"石寻托我修的旧镐放了三天。我嫌它钢口不够好，想重打一把，又怕显得他过去那些年全用错了东西。你帮我问问，他究竟想留什么。", "replies":[{"label":"先问他最在意哪一处。", "answer":"好。难得有件事，不能光靠敲得更用力解决。"}, {"label":"问问这把镐的来历。", "answer":"我只看见裂口，倒没问过它跟着谁走了多远。"}]},
		{"at":"shi_xun", "text":"那把镐陪我挖过第一个矿点，可我没打算让它陪我一辈子。想留下的只是柄上那道刻痕。严砧总把别人的信任当成不能失手。", "replies":[{"label":"让他保留木柄，换掉坏的部分。", "answer":"这就对了。用旧了不等于必须整件丢掉。"}, {"label":"留个纪念，工具可以换新。", "answer":"也行。纪念不该逼人拿着裂开的镐头下矿。"}]},
		{"at":"yan_zhen", "cost":{"ore":2}, "text":"矿石够试火了。他在意的原来不是一把永远不会坏的镐。我这几年倒把每件修理都当成了考试。", "replies":[{"label":"修理也可以留下过去。", "answer":"我会记着那道刻痕。你提醒我，手艺不只是把旧东西弄得像新的一样。"}, {"label":"先让下一次使用安心。", "answer":"好。把该换的换好，把原因讲清楚。这次我记住的是信任不用靠完美来换。"}]}
	]},
	"lin_sui": {"name":"林穗", "title":"账本上的一行空白", "coins":20, "steps":[
		{"at":"lin_sui", "text":"账本有一行只有名字，没有金额。是刚开店时温知帮我写的招牌钱，她总说以后再算。我怕一开口就显得见外。", "replies":[{"label":"当面问清楚，比猜着好。", "answer":"你替我开个头吧。这行空白比欠钱还让人惦记。"}, {"label":"先问她记得哪段开店的日子。", "answer":"那时候天天忙乱，倒很少好好聊过。"}]},
		{"at":"wen_zhi", "text":"招牌是我送的。开店第一天，林穗给路过的孩子每人一杯水，我觉得这条街从那天才真正有人气。请她别把所有善意都记成欠账。", "replies":[{"label":"我会把“送的”两字说清楚。", "answer":"谢谢。朋友之间也值得把话说明白。"}, {"label":"她也能把这份善意传下去。", "answer":"对，不必还给同一个人，更不必算成同一个价钱。"}]},
		{"at":"lin_sui", "text":"这一行终于能写完整了。我不是非要还清，只是不习惯有人无条件站在自己这边。你觉得写什么合适？", "replies":[{"label":"写“朋友赠送”。", "answer":"写好了。我会留着这行字，提醒自己不是每段关系都要结清。"}, {"label":"写“开店第一天的礼物”。", "answer":"这名字好。以后翻到这里，我会想起柜台边的水杯，也想起你替我们把话说开。"}]}
	]},
	"su_qin": {"name":"苏芩", "title":"给医师的晚饭", "coins":20, "steps":[
		{"at":"su_qin", "text":"我又忘了吃午饭。别人来诊所，我能把休息的话说得头头是道，轮到自己却总觉得再等一会儿。汤禾昨天把茶送到门口，我还没道谢。", "replies":[{"label":"让我帮你传声谢谢。", "answer":"麻烦你。也问问他那壶茶怎么泡的，别总聊工作。"}, {"label":"问问他怎么学会按时停下。", "answer":"我想听，可别让他笑得太大声。"}]},
		{"at":"tang_he", "text":"我也不是天生会休息。早年澡堂什么都想自己干，后来烧糊一锅水才肯分工。给苏芩带话：门关一小会儿，镇子不会散。", "replies":[{"label":"她也需要一个安心的停顿。", "answer":"对。不是表现够好了才配坐下来。"}, {"label":"请她把需要帮忙的事说出来。", "answer":"这句实在。人不是靠别人猜中才被照顾的。"}]},
		{"at":"su_qin", "cost":{"meal":1}, "text":"谢谢你带的饭。这次我会坐下来吃完。听见汤禾也弄砸过，我反倒轻松了些。以后你再见我忙得忘了时间，能提醒我一句吗？", "replies":[{"label":"饭凉了，先吃饭。", "answer":"就这句，简单最好。我会记得你没有劝我更努力，只是陪我把这一餐吃完。"}, {"label":"有什么能交给别人？", "answer":"好。我会先试着说出具体的需要，不再把忙当成不求助的理由。"}]}
	]},
	"tang_he": {"name":"汤禾", "title":"两只左脚木屐", "coins":18, "steps":[
		{"at":"tang_he", "text":"你来评评理，失物篮里两只木屐都写着“乔”，也都是左脚。他是打算凑齐一副再领，还是不知道自己有右脚？替我问问乔信，我昨天追出去，他已经跑没影了。", "replies":[{"label":"你确定两只都是左脚？", "answer":"我摆了一上午了，脚趾头都朝一边。去问他吧，再摆下去我也要怀疑自己的脚。"}, {"label":"我去问他另外两只在哪儿。", "answer":"对，问得具体些。别让他回一句“下次一定带走”就又跑了。"}]},
		{"at":"qiao_xin", "text":"啊，难怪家里两只也凑不上。我雨天穿木屐来，走时换布鞋，顺手只捡了靠门那一只。这事居然干了两回……你告诉汤禾，晚上我把右脚那两只送过去。", "replies":[{"label":"让他给你留个大一点的袋子。", "answer":"好，四只装一起，这回总不能再漏一边。袋口也请他系上。"}, {"label":"这回把左右脚一起数清楚。", "answer":"你别笑，我已经在送信本上写了：木屐，左二，右二。"}]},
		{"at":"tang_he", "delay":1, "text":"后来四只终于到齐了，我陪他一只一只数的。乔信还想顺便寄存在这里，说省得下雨跑回家。好家伙，失物篮都快成他鞋柜了。", "replies":[{"label":"给他写张“左右俱全”的收条。", "answer":"我写在认领簿上了：乔信，四只，两双，左右俱全。你作证，下回少一只可别算我头上。"}, {"label":"让他把两双都带回家。", "answer":"正合我意。袋子我亲手递过去了，连绳结都检查过。这回失物篮总算给别人腾出地方了。"}]}
	]},
	"zhou_chao": {"name":"周潮", "title":"没写进鱼讯的事", "coins":20, "steps":[
		{"at":"zhou_chao", "text":"年轻人问我哪片海鱼多，我张口就报方位。可今年连我也有扑空的时候。顾星想抄我的旧鱼讯，我怕那些笔记让他笑话。", "replies":[{"label":"让他看看变化，也看看空白。", "answer":"好。你先去问问，他是真想听，还是只想找标准答案。"}, {"label":"问问他需要记录什么。", "answer":"也是，也许我又替别人先下了结论。"}]},
		{"at":"gu_xing", "text":"我最想看的是扑空那几天。天气、潮水，还有周潮当时怎么判断的。经验不是永远猜中，是能把自己看见的东西讲明白。", "replies":[{"label":"我把这话带给他。", "answer":"请告诉他，错开的记录不是废纸。我的潮钟也教过我这个。"}, {"label":"你们可以把两种记录放一起。", "answer":"嗯。他看鱼，我看潮，至少能多问出几个好问题。"}]},
		{"at":"zhou_chao", "text":"旧鱼讯我没再藏了。人老了最怕说一句不知道，好像这些年就都白过了。听顾星这么一说，我倒想继续记。", "replies":[{"label":"把海的新变化记下来。", "answer":"好。旧经验不是把海定住，是帮我们看见它又变了。你让我敢在笔记上留问号。"}, {"label":"把判断的经过讲给年轻人。", "answer":"嗯，下一回我少报一个准地方，多讲讲自己为什么往那边走。你让我想起教人也可以一起学。"}]}
	]},
	"tian_qing": {"name":"田青", "title":"空着的田角", "coins":20, "steps":[
		{"at":"tian_qing", "text":"我留了一小块田没种，路过的人都问是不是荒了。其实那儿每年会长野花，沐桐画过。我有时也想，是不是该把每一寸都用起来。", "replies":[{"label":"去看看画里留下了什么。", "answer":"好。她看田的眼光和我不一样，也许能提醒我。"}, {"label":"问问她那些野花有什么特别。", "answer":"我天天路过，倒没认真叫出它们的名字。"}]},
		{"at":"mu_tong", "text":"田角有一种很小的花，收割之后才开。田青觉得它不算收成，我却靠它记住秋天来过。地不必每一块都用来证明人勤快。", "replies":[{"label":"我告诉她，这也是田的一部分。", "answer":"请说吧。画册里我没有把那一角涂成空白。"}, {"label":"让它留给下一季慢慢看。", "answer":"好。有些事只有留出地方，才会自己发生。"}]},
		{"at":"tian_qing", "delay":1, "text":"今天我没急着给田角下种。你帮我把一个小小的犹豫说清楚了。我想给它起个不那么像偷懒的名字。", "replies":[{"label":"就叫野花田。", "answer":"好，野花也有自己的位置。以后我再着急把日子排满，就看看这三个字。"}, {"label":"叫歇一季的地。", "answer":"这名字更合我心意。地和人一样，可以歇一阵，再决定下一步。"}]}
	]},
	"lu_yao": {"name":"陆遥", "title":"会指路的人", "coins":20, "steps":[
		{"at":"lu_yao", "text":"我能把镇里每条路讲得清清楚楚，轮到有人问我想去哪儿，却说不出来。乔信去过不少地方，我想问他，又怕显得自己白待了这么多年。", "replies":[{"label":"问旅途，也问他为什么回来。", "answer":"这问题好。帮我听听，我不想只听远方有多好。"}, {"label":"问他第一次出门怕不怕。", "answer":"我更想知道这个，只是一直不好意思说。"}]},
		{"at":"qiao_xin", "text":"第一次送远路，我把地址念了一整晚。后来才知道，去远方和留在家都不是考试。陆遥想走一段就走，想回来也不用准备解释。", "replies":[{"label":"这句话比路线有用。", "answer":"带给她吧。我能教认路，不能替她决定去哪儿。"}, {"label":"先从一段不太远的路开始。", "answer":"也好，不必把第一次出门变成一生的决定。"}]},
		{"at":"lu_yao", "text":"我给自己画了张小地图，第一站没画得很远。原来向别人问路，并不会让我失去引路员这个身份。", "replies":[{"label":"走到哪儿，都可以回来。", "answer":"我把这句写在地图背面。你让我觉得，出发不必先和这里告别。"}, {"label":"也可以发现自己还是喜欢留下。", "answer":"嗯。留下也可以是重新选过的答案。我会记得，你没替我把路选好。"}]}
	]},
	"chen_yu": {"name":"陈鱼", "title":"鱼汤不要鱼", "coins":22, "steps":[
		{"at":"chen_yu", "text":"林穗托人捎来一张午饭单：鱼汤，不要鱼。我看了三遍，还是这五个字。她要是想喝热水，我也会烧。你路过店里，替我问清楚到底下不下鱼。", "replies":[{"label":"也许后面漏了一个字。", "answer":"那最好。我都快把“鱼汤”这两个字拆开琢磨了。"}, {"label":"你打算先烧水？", "answer":"水已经滚了，鱼还在等消息。劳驾快去一趟，别让它们等到下班。"}]},
		{"at":"lin_sui", "text":"我写的是不要鱼刺！最后那个字写在纸角，撕单子时掉了。我们几个要边盘货边吃，谁有空一根根挑。请陈鱼把鱼肉剔好，我没让他端一锅白水来。", "replies":[{"label":"我把少的那个字带回去。", "answer":"麻烦你，强调一下，是鱼刺。估计他已经在厨房笑我了。"}, {"label":"下次先把要求写在纸中间。", "answer":"行，下次我写大字。省得一顿午饭还得请你们破案。"}]},
		{"at":"chen_yu", "cost":{"fish":2}, "text":"鱼刺！我就说她不至于专门订一锅水。带两条鱼来吧，我先剔一份试试，看看细刺有没有漏。今天这张单子可得记下来。", "replies":[{"label":"备注写清楚：剔刺，多留鱼肉。", "answer":"写好了，字挤在纸中间。以后林穗再来订饭，我先确认纸角齐不齐。今天算咱们合办的一桩小案子。"}, {"label":"给这次午饭取名“丢了一个字”。", "answer":"哈，那我就在厨房笔记里这么记。丢一个字，差点省两条鱼。这笑话够我和林穗讲好一阵了。"}]}
	]},
	"wen_zhi": {"name":"温知", "title":"树林里谁在敲门", "coins":20, "steps":[
		{"at":"wen_zhi", "text":"今天三份作文都写了树林里的敲门声，一份说是啄木鸟，一份说是木匠，最后一份写树在催人回家吃饭。我没去听过，批到这里卡住了。森柯应该知道那声音。", "replies":[{"label":"我去问问，先别判树说错。", "answer":"好，树催饭那份写得还挺认真。我先把红笔放下。"}, {"label":"木匠看过这份作文吗？", "answer":"没有，千万别先给贺木看。他会问我那棵树按天算工钱还是按件算。"}]},
		{"at":"sen_ke", "text":"哦，那阵咯噔声。林边两根枯枝碰在一起，风一吹就响，我上回也以为有人敲门。风停了，它比谁都安静。温知要讲的话，顺便说说，别为了听声往树底下钻。", "replies":[{"label":"原来是风在敲。", "answer":"嗯，而且敲得没个准点。孩子问几时能听见，我可开不了课表。"}, {"label":"它确实很像坏掉的门栓。", "answer":"对，就是那种想关紧却总差一点的声音。你这么说，温知应该能讲明白。"}]},
		{"at":"wen_zhi", "delay":1, "text":"今天把两根树枝的事讲了，写木匠的孩子说，那贺木至少该去修修。现在大家争着给这段小故事起标题，我已经听了七个“神秘敲门人”了。", "replies":[{"label":"《没有门的敲门声》。", "answer":"这个好，先把他们骗进去，再讲树枝。今天这堂课的记录就用它了；要是孩子们来问谜底，你可别太快说。"}, {"label":"《树的门栓坏了》。", "answer":"我喜欢这个。连森柯说的声音都有了。课堂记录里我会写上你的题目，旁边再注明：不必请木匠。"}]}
	]},
	"qiao_xin": {"name":"乔信", "title":"一路叮当的包裹", "coins":18, "steps":[
		{"at":"qiao_xin", "text":"汤禾有个包裹，我一走它就叮当，停下它也停。我真没摔过，外面也没写易碎。我先放稳了，你帮我问问他订了什么，免得我抱着一箱碎片往澡堂跑。", "replies":[{"label":"我去问，先别晃它了。", "answer":"我没晃，是走路就响……好，我把手也放开。"}, {"label":"会不会原本就是铃铛？", "answer":"要真是铃铛，我这一路算替他验货了。你去确认一下，我可不敢拆别人的包裹。"}]},
		{"at":"tang_he", "text":"一套空茶罐，薄铁皮的，套在一起当然响。我让商家少包几层，没想到省下的纸全变成乔信的担心了。你告诉他，走着送来就行，不必捧着。", "replies":[{"label":"他听见是铁皮应该能放心。", "answer":"放心，磕个小瘪也能装茶。他把信送对门，比让茶罐一点不响要紧。"}, {"label":"下次请商家塞点纸隔开。", "answer":"行，这点纸钱我不省了。总不能每买一次茶罐，就请你跑一趟解释。"}]},
		{"at":"qiao_xin", "text":"铁皮茶罐，难怪响得那么精神。刚才我连过门槛都分了三步。总算能照常送过去了，签收备注写点什么，你替我拿个主意？", "replies":[{"label":"写“内装茶罐，声响正常”。", "answer":"记好了，规规矩矩这一句。哪天有人再问起，我就翻给他看，不必再陪茶罐一起紧张。"}, {"label":"写“沿途自带伴奏”。", "answer":"哈哈，这句留在我自己的送信本上，正式回单还是写茶罐。今天这趟路，我连它响几下都快背下来了。"}]}
	]},
	"shi_xun": {"name":"石寻", "title":"那次没有下井", "coins":22, "steps":[
		{"at":"shi_xun", "text":"有次我听见矿道里不对劲，退回来了。后来没塌，可我一直觉得那天像逃跑。苏芩帮我包手时说了句话，我没听进去。", "replies":[{"label":"再听一次，也许现在不同。", "answer":"你替我问问吧。我当时光顾着替自己解释。"}, {"label":"问她怎样看那次返回。", "answer":"嗯。我一直只听见脑子里那个嫌自己胆小的声音。"}]},
		{"at":"su_qin", "text":"我说的是，回来的人才能说明白听见了什么。石寻的手是抓绳磨伤的，不是逞强的凭证，也不是退缩的证据。谨慎不用靠真的塌一次才有价值。", "replies":[{"label":"安全回来本身就值得肯定。", "answer":"请告诉他。不出事不是判断没有意义。"}, {"label":"把听见的危险认真记下来。", "answer":"好。让经验成为提醒，不要成为惩罚自己的办法。"}]},
		{"at":"shi_xun", "delay":1, "text":"我终于把那天写进矿记，没有再划掉返回两个字。下井前看天色、听石声，这些事我还会做，只是不想再拿命证明勇敢了。", "replies":[{"label":"把返回也当作本事。", "answer":"嗯。以后有人问最重要的矿工本事，我会说知道何时回来。这是你帮我找回的答案。"}, {"label":"把那段记录讲给新来的人。", "answer":"我会讲，包括自己犹豫的那一段。他们不必只听见漂亮的发现，也该听见安全的退路。"}]}
	]},
	"sen_ke": {"name":"森柯", "title":"倒下的老树", "coins":20, "steps":[
		{"at":"sen_ke", "text":"林里那棵老树倒了，我守了它那么多年，总觉得是自己没照顾好。沐桐说倒木上有新东西，我还没认真看。", "replies":[{"label":"听听她看见了什么。", "answer":"好。也许我这些天只顾着盯树根。"}, {"label":"问问她会怎样画这棵树。", "answer":"我不想只留下它还站着的时候。去问问吧。"}]},
		{"at":"mu_tong", "text":"倒木底下冒了菌子，断口留着好几圈年轮。我画的不是一棵失败的树，是它换了个样子留在林里。森柯不必替每一次变化负责。", "replies":[{"label":"把新的生命讲给他。", "answer":"请说得细一点。他熟悉每一棵树，会听懂的。"}, {"label":"也让他有时间难过。", "answer":"你说得对。有新芽，不等于不能舍不得老树。"}]},
		{"at":"sen_ke", "cost":{"mushroom":1}, "text":"这朵林菇像倒木旁的那一簇。我想把它画进观察簿，旧树的记录不结束，只是换一页。你觉得这一页从哪儿写起？", "replies":[{"label":"从它现在养着的东西写起。", "answer":"好。护林不只是让树一直站着，也包括看见倒下以后。我会记得你带我看了脚边。"}, {"label":"先写你想念它的样子。", "answer":"嗯。我可以一边怀念，一边看新变化。谢谢你没有催我赶快想开。"}]}
	]},
	"bai_fan": {"name":"白帆", "title":"只买箱子的订单", "coins":24, "steps":[
		{"at":"bai_fan", "text":"乔信订了一只空箱，特意写了三遍“空”。我这船又不是卖空气的。我想塞点用得上的小货，他把赠品也划掉了。你去问问，他到底准备拿箱子装什么？", "replies":[{"label":"也许他真的只缺一个箱子。", "answer":"我知道，可这么大的箱子空着过海，总让我觉得漏装了货。问清楚，我就封箱。"}, {"label":"你以前是不是送过太多赠品？", "answer":"那叫照顾熟客。好吧，上回两只杯子确实把他要的信封压皱了。你别特意提那事。"}]},
		{"at":"qiao_xin", "text":"我要收旧邮路册，尺寸都量好了，就缺一只干燥的空箱。上回白帆塞进来的杯子我现在还没用完。拜托，连“顺手附赠”也别有。", "replies":[{"label":"我把不附赠三个字带回去。", "answer":"最好原话带到。白帆一听“随便”，总能再装半箱东西。"}, {"label":"封箱前让他再看一遍尺寸。", "answer":"这个可以。册子摊开多宽我都写了，箱子合适就行，别拿赠品填空。"}]},
		{"at":"bai_fan", "text":"原来是装邮路册。好，干燥，尺寸合适，里面空着。瞧，我连手里这根备用绳都没往里放。现在只差货单上怎么写，省得下回我自己看不明白。", "replies":[{"label":"写“空箱一只，禁止附赠”。", "answer":"行，我照写，后头再画一道线。这单生意我算记牢了：乔信花的钱，就是要买箱子里面那块空地方。"}, {"label":"写“邮路册专用箱”。", "answer":"这就顺眼多了。我在订单上记了用途，手也不会总想着往里塞东西。等乔信收好册子，我倒想听听他那些旧路线。"}]}
	]},
	"chi_sheng": {"name":"赤绳", "title":"海盗的绝密烤鱼术", "coins":24, "steps":[
		{"at":"chi_sheng", "text":"我烤的鱼外面黑了，里面还凉。周潮说离火远点，我就把整个人往后挪，结果鱼掉进火里了。你再去问清楚，远的是我，还是鱼？别找陈鱼，他会拿看病的眼神看我。", "replies":[{"label":"八成说的是鱼。", "answer":"我也这么想，可这回得问准。晚饭不能再靠猜了。"}, {"label":"你后退时把鱼也带走了吗？", "answer":"带了，木棍没拿稳。别问细节，周潮知道怎么烤，你去找他。"}]},
		{"at":"zhou_chao", "text":"我让他把鱼抬高一点，他端着整根木棍往后退。火蹿那么高，还一个劲儿添柴，像嫌鱼跑得不够快。告诉他先等火稳下来，别拿晚饭演海战。", "replies":[{"label":"我让他少添两把柴。", "answer":"对，还得转着看，别烤完一面才想起另一面。他做事老爱一口气冲到底。"}, {"label":"带条烤好的鱼让他对照。", "answer":"也行。至少先让他认清正常的颜色，别再说黑得均匀就是熟了。"}]},
		{"at":"chi_sheng", "cost":{"cooked_fish":1}, "text":"你带条烤鱼给我当样子吧。这回我记下了：火别太冲，鱼抬高，记得翻面。原来不需要往后撤。我打算把这几条写下来，取个响亮的名字。", "replies":[{"label":"《周潮教我的烤鱼办法》。", "answer":"啧，一点都不威风。不过确实是他教的，就这么写。以后谁来问，我把这页摊开，省得再有人跟着我往后撤。"}, {"label":"《没有阵亡的晚饭》。", "answer":"这个好！我写在自己的笔记上了。下面补一行：周潮口述，你负责传话。我负责……至少下次把鱼拿稳。"}]}
	]},
	"chao_jia": {"name":"潮甲", "title":"潮水挪过的归途", "coins":22, "steps":[
		{"at":"chao_jia", "text":"我记得回来的沙滩有一块白石，如今潮水把它盖住了。族里年轻的说换个地方吧，我怕一换，就忘了来路。澜影听得见更深处的潮。", "replies":[{"label":"我替你去听听深处的记忆。", "answer":"请慢慢问。海里的记忆，不总是石头的形状。"}, {"label":"问问潮水带走了什么，又留下什么。", "answer":"这问题很好。我已经很久只问它拿走了什么。"}]},
		{"at":"lan_ying", "text":"白石还在那里，只是上面多了一层沙。潮甲记得的不仅是石头，还有同行者在水里的声音。路会变，认得彼此的方式可以留下。", "replies":[{"label":"把同行者的声音带回话里。", "answer":"去吧。告诉它，归途不只刻在岸上。"}, {"label":"告诉它，不必守着同一个标记。", "answer":"嗯。海不会要求生命为一块旧石头停住。"}]},
		{"at":"chao_jia", "delay":1, "text":"我把白石的故事讲给年轻的听，也听了它们认路的办法。原来让它们走在前面，不等于把过去扔掉。", "replies":[{"label":"把旧路讲成故事。", "answer":"好。白石会留在讲述里，脚下走今天的沙。你让我明白，传下去不一定要原地不动。"}, {"label":"和它们一起认新的路。", "answer":"我会跟上它们的声音。这次我记住的归途里，也有年轻者教我的那一段。"}]}
	]},
	"tai_lu": {"name":"苔露", "title":"种子不答应的事", "coins":20, "steps":[
		{"at":"tai_lu", "text":"我把种子放到林间，想让它们排成小时候的花纹。可它们有的不发芽，有的偏往石缝长。田青总和种子打交道，她会让它们听话吗？", "replies":[{"label":"我问问她怎样等待。", "answer":"等待也有办法吗？我想听。"}, {"label":"问问她会不会也改变计划。", "answer":"也许花纹不一定非得像我记得的那样。"}]},
		{"at":"tian_qing", "text":"我会选土、浇水，也会看哪儿不合适。但种子不欠我一个整齐的结果。告诉苔露，照料和命令不是同一回事。", "replies":[{"label":"把合适的条件留给种子。", "answer":"对，剩下的留给季节和时间。"}, {"label":"也给自己换个想法的余地。", "answer":"嗯。田地不按图纸长，人也可以跟着学。"}]},
		{"at":"tai_lu", "cost":{"fiber":3}, "text":"这些纤维可以替我捆好观察小册。旧花纹我不再强求了，想把种子自己选的位置记下来。你觉得我该先看什么？", "replies":[{"label":"看它们真正喜欢哪里。", "answer":"我要学会跟着芽尖看世界。你带来的不是让种子听话的方法，是听它们说话的耐心。"}, {"label":"看意料之外会长出什么。", "answer":"好。我把空白也留在册子里。新林子不必证明旧花纹正确，这句话我会一直记着。"}]}
	]},
	"lan_ying": {"name":"澜影", "title":"没被翻译的歌", "coins":24, "steps":[
		{"at":"lan_ying", "text":"你听懂潮语以后，我反倒不知道该唱哪一首。你们总问每个声音是什么意思，可有一段歌，只是月亮照进水里时唱的。温知也会替声音找文字吗？", "replies":[{"label":"我问问她，是否什么都需要翻译。", "answer":"请带着这个问题去，不必替我找一句漂亮的解释。"}, {"label":"我想听她怎样教人理解。", "answer":"也好。理解也许不只是一一对应。"}]},
		{"at":"wen_zhi", "text":"我没听过那首歌，不能替澜影解释。我会先问它愿不愿意唱，再承认自己听不懂的地方。靠近另一种生活，不是把它全改写成我们的词。", "replies":[{"label":"把不能解释的部分也留下。", "answer":"对。诚实地留白，比替它说一个答案好。"}, {"label":"先听，再问它愿意分享什么。", "answer":"请把这个顺序带回去。对话需要的不只是一门语言。"}]},
		{"at":"lan_ying", "delay":1, "text":"那我在自己的记忆里给你留一段位置。这回不用把每一个起伏写成字。你想怎样记住这首还没唱完的歌？", "replies":[{"label":"记住我们一起听潮的时刻。", "answer":"好。这段歌会属于一个共同待过的时刻，不必属于同一句解释。我会记得你愿意听。"}, {"label":"让它保留自己的名字和空白。", "answer":"那就不把它改成岸上的歌。我会记得，你懂了语言之后，仍肯尊重没有译完的部分。"}]}
	]},
	"cen_po": {"name":"岑婆", "title":"不带怀表的散步", "coins":22, "steps":[
		{"at":"cen_po", "text":"刚退下来那阵子，我嘴上说去散步，手却隔五分钟摸一回口袋里的旧怀表。今天特意没给它上发条，走到东街竟不知往哪拐了。陆遥平时给旅人指路，遇到不赶路的人怎么推荐？", "replies":[{"label":"我去问问陆遥平时怎么闲逛。", "answer":"去吧。别说是我问的，不然她又要端端正正给我画张标准路线图了。"}, {"label":"顺便听听镇上哪条小路最适合发呆。", "answer":"哈哈，『发呆路线』这个词新鲜，我干了四十年领航还没走过呢。"}]},
		{"at":"lu_yao", "text":"不赶路的话，我反倒建议把地图折起来揣兜里——顺着石阶听哪边风声轻就往哪边走，走岔了也不过多看两棵树。要是岑婆散步渴了，带两杯淡水陪她坐会儿比指路管用。", "replies":[{"label":"好主意，不设终点才算真散步。", "answer":"对呀，我在镇里重画路牌时，最喜欢的也是那些没写进正图的石阶拐角。"}, {"label":"我带两杯淡水去陪她慢慢走。", "answer":"她嘴硬心软，有人不催她看钟点、安安静静喝杯水，她准高兴。"}]},
		{"at":"cen_po", "delay":1, "cost":{"freshwater":2}, "text":"昨晚我照陆遥说的没看表，顺着风声走到芦苇边看了一整晚归鸟。这两杯水正好润嗓子——你说我这只停了的旧怀表以后怎么留着好？", "replies":[{"label":"揣在兜里，提醒自己今天不赶时间。", "answer":"这法子妙！每次摸到冰凉的表壳，就知道潮水自己会涨落，不用我吹哨子催它了。"}, {"label":"摆在窗边当镇纸，压住没写完的游记。", "answer":"哈哈，压游记好！走一处记一页，什么时候翻开都不算晚。"}]}
	]},
	"a_yuan": {"name":"阿沅", "title":"擦不掉的那笔红漆", "coins":20, "steps":[
		{"at":"a_yuan", "text":"早上给渔铺补描红字招牌，一阵海风吹来，袖口和画板边都蹭上了一道朱砂漆，怎么洗都留着浅印子。沐桐画植物图鉴向来干干净净，她弄脏画纸时都怎么补救呀？", "replies":[{"label":"我去农庄找沐桐取取经。", "answer":"帮我问问她！我总不好意思举着花花绿绿的袖子去敲门。"}, {"label":"说不定沐桐也有画歪的时候。", "answer":"要是连她都有擦不掉的墨点，我可就放心多啦。"}]},
		{"at":"mu_tong", "text":"其实我的速写本边角也全是草汁印子！植物叶脉讲究如实，可店招和生活速写有温度才好看——要是不嫌弃，让她拿两块木板把那道红漆改画成一枚落款小印章吧。", "replies":[{"label":"把失误改成落款印章，太巧妙了。", "answer":"阿沅画的本来就是热热闹闹的人间烟火，多一点真颜料痕迹反而亲切。"}, {"label":"我带两块试色木板回去告诉她。", "answer":"顺便替我跟她说，下回我们可以交换颜料用！"}]},
		{"at":"a_yuan", "cost":{"wood":2}, "text":"把擦不掉的红漆描成落款印章？沐桐这主意绝啦！这两块木板正好拿来试新落款，你觉得我画成什么小记号最像我？", "replies":[{"label":"画一把歪着腿的小木凳。", "answer":"哈哈，一眼就知道是我画的！以后镇上哪块木牌角落有红漆小板凳，那就是我的手笔。"}, {"label":"就留原本那道海风吹歪的红笔触。", "answer":"也是！海风帮我添的一笔，比拿尺子量出来的方印章更鲜活，我就大大方方留着它啦。"}]}
	]},
	"mi_luo": {"name":"米洛", "title":"少了一齿的八音梳", "coins":24, "steps":[
		{"at":"mi_luo", "text":"我在暗礁缝里捡到一只小八音盒，发条修好了，音梳却断了一根齿，每转一圈到中间就漏掉一拍。海洞三层的澜影最懂水里的回音，它听见缺了一拍的曲子会觉得难听吗？", "replies":[{"label":"我潜去三层请澜影听听这段节奏。", "answer":"替我记准那处空拍的位置！要是难听，我就再找铜片硬焊一齿上去。"}, {"label":"也许海里的歌本来就有停顿。", "answer":"咦，岸上的齿轮总是一个咬一个从不停气，我去听听澜影怎么说！"}]},
		{"at":"lan_ying", "text":"每转一圈停一拍？那不就像海浪拍在礁石上、退回去换一口气的间隙吗？要是把每一拍都填得满满当当，水里的回声反而撞在一起听不清了。", "replies":[{"label":"把换气的停顿原样带回给米洛。", "answer":"告诉它，留出那一拍空白的时候，周围的潮水会替八音盒唱完那一下。"}, {"label":"修好外壳就好，不必强补断齿。", "answer":"对，完好不一定要密不透风，能和海水合上拍子就是好声音。"}]},
		{"at":"mi_luo", "delay":1, "cost":{"scrap":2}, "text":"我昨晚试着没补那根断齿，只用这两块废金属把共鸣盒底板加固了——结果一到漏拍的地方，礁洞水滴声刚好『叮』地接上！你说这只八音盒该摆在哪儿？", "replies":[{"label":"放在空气洞边，给下潜的人报平安。", "answer":"好主意！听见这声留着换气拍子的轻响，大家就知道离补氧的洞口不远啦。"}, {"label":"留在修补石台旁，陪你一起听潮。", "answer":"嘿嘿，那以后我修太入神忘了歇手，听见那一拍空隙就知道该伸个懒腰啦！"}]}
	]},
	"san_jin": {"name":"三斤", "title":"圆石头的交换规矩", "coins":18, "steps":[
		{"at":"san_jin", "text":"三斤把一颗海浪磨圆的白石子和一只生锈铁皮盖并排摆在礁石边，拿前鳍拨了拨白石子，又歪头望向岸边渔铺的方向，喉咙里发出咕噜声。", "replies":[{"label":"去渔铺问问周潮它是不是又捡了东西。", "answer":"三斤见你点头，欢快地拍了两下肚皮，用下巴把那只铁皮盖压住了。"}, {"label":"先收下它的善意，去问问周潮怎么回礼。", "answer":"三斤把白石子往你脚尖前又推近半寸，胡须得意地翘了起来。"}]},
		{"at":"zhou_chao", "text":"哈哈，三斤这是拿你当熟人了！海豹爱捡圆溜溜的小玩意儿炫耀，你可别拿大鱼回礼惯坏它的胃口；带两份干净海苔去替它铺铺晒背垫，再把生锈铁盖收走免得划着它前鳍就行。", "replies":[{"label":"收走尖铁盖、铺上海苔垫，两全其美。", "answer":"对喽，既护着它爪子，又不把它养成追船讨食的懒性子。"}, {"label":"我带两份海苔回珊湾跟它换。", "answer":"去吧，看你懂它的规矩，它准保给你翻个肚皮瞧瞧！"}]},
		{"at":"san_jin", "cost":{"seaweed":2}, "text":"你把松软的海苔垫铺在礁石边，顺手替它收起那只生锈铁皮盖。三斤凑过来嗅了嗅海苔清香，心满意足地滚了一圈，仰起头等你拍拍。", "replies":[{"label":"轻轻拍拍木板边，和它保持礼貌距离。", "answer":"三斤懂事地跟着拍了两下前鳍，把那颗温润的条纹白石留在了你手边，安安心心眯起眼晒太阳。"}, {"label":"指指大海，约它下次顺潮再见。", "answer":"三斤神气地昂头打了个响鼻，滑进浅水挽出一串水花，又探出圆脑袋朝你眨了眨眼。"}]}
	]},
}

static func create() -> Dictionary:
	return {"host":{}, "guest":{}}

static func _record(data:Dictionary, slot:String, owner:String) -> Dictionary:
	return data.get("stories", {}).get(slot, {}).get(owner, {"step":0, "day":0, "choices":[]})

static func entries(data:Dictionary, slot:String, npc:String) -> Array:
	if slot not in ["host", "guest"] or not ARCS.has(npc): return []
	var result:Array = []
	for owner:String in ARCS:
		var arc:Dictionary = ARCS[owner]
		var step:int = int(_record(data, slot, owner).step)
		var target:String = owner if step == 3 else str(arc.steps[step].at)
		if target != npc: continue
		result.append({"action":"town_personal_open", "label":("回忆 · " if step == 3 else "人物故事 · ") + str(arc.title), "args":{"id":npc, "story":owner, "step":step}})
	return result

static func _valid(data:Dictionary, slot:String, args:Dictionary, reply:bool) -> bool:
	if slot not in ["host", "guest"] or not data.get("stories") is Dictionary or not data.stories.get(slot) is Dictionary: return false
	if args.size() != (4 if reply else 3) or not args.has_all(["id", "story", "step"]): return false
	if not args.id is String or not args.story is String or not ARCS.has(args.story) or not ARCS.has(args.id): return false
	if not integer(args.step, 0, 2 if reply else 3): return false
	var record:Dictionary = _record(data, slot, args.story)
	var step:int = int(record.step)
	if int(args.step) != step: return false
	var target:String = str(args.story) if step == 3 else str(ARCS[args.story].steps[step].at)
	if args.id != target: return false
	if reply:
		if not args.has("reply") or not integer(args.reply, 0, ARCS[args.story].steps[step].replies.size() - 1): return false
	return true

static func _cost_text(cost:Dictionary) -> String:
	var parts:PackedStringArray = []
	for item:String in cost: parts.append("%s ×%d" % [Inventory.ITEM_NAMES[item], int(cost[item])])
	return "、".join(parts)

static func _waiting(data:Dictionary, slot:String, owner:String) -> bool:
	var record:Dictionary = _record(data, slot, owner)
	var step:int = int(record.step)
	if step == 0 or step == 3: return false
	return int(data.day) < int(record.day) + int(ARCS[owner].steps[step].get("delay", 0))

static func open(data:Dictionary, slot:String, args:Dictionary) -> String:
	if not _valid(data, slot, args, false): return "这段对话已有变化，请重新和对方聊聊。"
	var arc:Dictionary = ARCS[args.story]
	var record:Dictionary = _record(data, slot, args.story)
	var step:int = int(record.step)
	if step == 3:
		return "%s · %s\n\n%s\n\n你们记得这次选择；故事奖励已经领取。" % [arc.name, arc.title, arc.steps[2].replies[int(record.choices[2])].answer]
	var beat:Dictionary = arc.steps[step]
	var result:String = "%s · %s\n\n%s" % [ARCS[args.id].name, arc.title, beat.text]
	if beat.has("cost"): result += "\n\n继续这段对话会交付：" + _cost_text(beat.cost) + "。"
	if _waiting(data, slot, args.story): result += "\n\n让对方想一想，过一夜再来继续；没有截止日期。"
	return result

static func replies(data:Dictionary, slot:String, args:Dictionary) -> Array:
	if not _valid(data, slot, args, false) or int(args.step) == 3 or _waiting(data, slot, args.story): return []
	var result:Array = []
	var options:Array = ARCS[args.story].steps[int(args.step)].replies
	for index:int in options.size():
		result.append({"action":"town_personal_reply", "label":str(options[index].label), "args":{"id":args.id, "story":args.story, "step":int(args.step), "reply":index}})
	return result

static func action(data:Dictionary, player:Dictionary, slot:String, args:Dictionary) -> String:
	if not _valid(data, slot, args, true): return "这段对话已有变化，请重新和对方聊聊。"
	if not integer(data.get("money"), 0, MONEY_LIMIT) or not integer(data.get("day"), 1, 1000000): return "钱袋或日期记录异常，故事进度保持不变。"
	if not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE): return "背包记录异常，材料和故事进度保持不变。"
	if not data.get("journal") is Dictionary or not data.journal.get(slot) is Dictionary or not data.journal[slot].get("friendship") is Dictionary: return "手记记录异常，故事进度保持不变。"
	var owner:String = str(args.story)
	if _waiting(data, slot, owner): return "让对方想一想，过一夜再来继续；故事不会过期。"
	var step:int = int(args.step)
	var arc:Dictionary = ARCS[owner]
	var beat:Dictionary = arc.steps[step]
	var coins:int = int(arc.coins) if step == 2 else 0
	if int(data.money) + coins > MONEY_LIMIT: return "共同钱袋已满，材料和故事进度都保留。"
	var bag:Array = player.bag.duplicate(true)
	var cost:Dictionary = beat.get("cost", {})
	for item:String in cost:
		if Inventory.count(bag, item) < int(cost[item]): return "还需要%s。材料和故事进度都保留，准备好再来。" % _cost_text(cost)
		Inventory.remove(bag, item, int(cost[item]))
	var record:Dictionary = _record(data, slot, owner).duplicate(true)
	record.step = step + 1
	record.day = int(data.day)
	record.choices.append(int(args.reply))
	player.bag = bag
	data.stories[slot][owner] = record
	data.money = int(data.money) + coins
	var affection:int = 20 if step == 2 else 10
	var friendships:Dictionary = data.journal[slot].friendship
	friendships[owner] = mini(1000, int(friendships.get(owner, 0)) + affection)
	var result:String = str(beat.replies[int(args.reply)].answer)
	if step == 2: return result + "\n\n故事完成 · +%d金币 · %s好感+%d。选择已记在J手记。" % [coins, arc.name, affection]
	var next:Dictionary = arc.steps[step + 1]
	return result + "\n\n%s找%s聊聊，接着听这段故事。%s好感+%d。" % ["过一夜再" if next.get("delay", 0) > 0 else "有空时", ARCS[next.at].name, arc.name, affection]

static func restore(value:Variant, day:int) -> Dictionary:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["host", "guest"]): return {}
	var result:Dictionary = create()
	for slot:String in ["host", "guest"]:
		if not value[slot] is Dictionary or value[slot].size() > ARCS.size(): return {}
		for owner in value[slot]:
			if not owner is String or not ARCS.has(owner): return {}
			var record:Variant = value[slot][owner]
			if not record is Dictionary or record.size() != 3 or not record.has_all(["step", "day", "choices"]): return {}
			if not integer(record.step, 1, 3) or not integer(record.day, 1, day) or not record.choices is Array or record.choices.size() != int(record.step): return {}
			var choices:Array = []
			for index:int in record.choices.size():
				if not integer(record.choices[index], 0, ARCS[owner].steps[index].replies.size() - 1): return {}
				choices.append(int(record.choices[index]))
			result[slot][owner] = {"step":int(record.step), "day":int(record.day), "choices":choices}
	return result

static func summary(data:Dictionary, slot:String) -> String:
	if slot not in ["host", "guest"]: return ""
	var active:PackedStringArray = []
	var finished:PackedStringArray = []
	for owner:String in ARCS:
		var record:Dictionary = _record(data, slot, owner)
		var step:int = int(record.step)
		if step == 0: continue
		var arc:Dictionary = ARCS[owner]
		if step == 3:
			finished.append("[b]%s · %s[/b]\n你的回答：%s\n%s" % [arc.name, arc.title, arc.steps[2].replies[int(record.choices[2])].label, arc.steps[2].replies[int(record.choices[2])].answer])
			continue
		var beat:Dictionary = arc.steps[step]
		var line:String = "[b]%s · %s[/b]（%d/3）\n接下来找%s。" % [arc.name, arc.title, step, ARCS[beat.at].name]
		if _waiting(data, slot, owner): line += " 过一夜再继续。"
		if beat.has("cost"): line += " 带上" + _cost_text(beat.cost) + "。"
		line += "\n你上次说：" + str(arc.steps[step - 1].replies[int(record.choices[step - 1])].label)
		active.append(line)
	var result:String = "[b]人物故事[/b]\n这些故事各自记录，不限时，也不影响建设和出海。\n"
	result += "\n还没有开始。和居民聊聊，选择人物故事即可。" if active.is_empty() and finished.is_empty() else ""
	if not active.is_empty(): result += "\n" + "\n\n".join(active)
	if not finished.is_empty(): result += "\n\n[b]一起留下的回忆[/b]\n" + "\n\n".join(finished)
	return result

static func integer(value:Variant, low:int, high:int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floorf(float(value)) == float(value) and value >= low and value <= high
