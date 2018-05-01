// This file is a contribution by 3iff.

/* AI company naming code. Originally designed for EmotionAI v9.
   Names are English based. It's quite simple to add or change names if desired.
   It should be quite easy to incorporate this into other AI newgrfs.
   Various naming formats, personal names, initials, generalised company names and town names.

   Version 1.02 August 2015
   Copyright (C) 2015 3iff.
   Licensed under GPL(v2)

   Thanks to Brumi for writing EmotionAI - which allowed me to create this mod.

*/

/* Notes:
   We load all the data into the function.
   Name data isn't indented to make it easier to see the whole line in the text editor.
   Names are grouped sort-of alphabetically or by general type to make it easier to read.

   Data entries and new name classes can be added (or removed) as you wish.
   New name formats can be added: just give them a case value and amend the code to select the new name format.
   If you do add interesting stuff, I'd appreciate seeing what you come up with.
   You can contact me (3iff) at the ottd forum.

   To add this to other AI scripts, simply add this file and make this call when a new company is created.
   SetCo.SetCompanyName();
*/

class SetCo extends AIController
{
}

function SetCo::SetCompanyName(town_id)
{
  // Surnames
  local co_ai_name = [
    "Anderson","Atkins","Allen","Adder","Austin","Adams","Alderton","Andrews","Archer","Abbott","Appleby","Atkinson"
    "Brooks","Baldwin","Badger","Boddley","Bunn","Bewley","Blackwell","Beresford"
    "Bull","Buxton","Burton","Bixby","Blake","Booth","Ball","Boot","Black","Brown","Burgess","Brewster"
    "Bowman","Bailey","Baker","Barnes","Barrett","Barton","Baxter","Birch","Beaumont"
    "Bennett","Bell","Bishop","Bright","Brent","Brewster","Bryant","Bradley","Berry","Burns"
    "Carpenter","Collins","Cunningham","Crowe","Campbell","Cox","Clarke","Carter","Chapman"
    "Cook","Cooper","Cousins","Crawford","Curtis","Cuthbert","Clayton","Cowan","Cross"
    "Denning","Davis","Dawson","Day","Davidson","Dale","Drake","Dent","Duncan"
    "Edwards","Etting","Ellis","Ecclestone","Emmerson","Evans","Eagles","Earnshaw","Elliott","Ellis"
    "Finch","Fletcher","Foster","Ford","Fenton","Frost","Farnsworth","Fisher","Farmer","Farrell","Franklin"
    "Ferris","Floyd","Finch","Fitzpatrick","Ford","Forbes","Fowler","Fox","Franklin"
    "Garfield","Grommett","Gray","Gibson","Griffiths","Griffin","Gibbons","Goddard","Gilbert","Goddard","Goodwin"
    "Green","Greenhill","Groom","Gibbs","Graham"
    "Hamilton","Harrison","Higgins","Hughes","Hudson","Holmes","Hall","Hawkins","Hammond","Harvey","Hawkins"
    "Howard","Houghton","Harris","Hayes","Hackett","Hanratty","Hood","Horton","Hodges","Hatton"
    "Ivey","Ingle","Jones","Jackson","Johnson","Jacobs","Jarvis","Jennings","Jeffries","Jenkins"
    "Killik","Keith","King","Kelly","Kemp","Knox","Keene","Kirk","Knight"
    "Locke","Lowe","Laidlaw","Lewis","Lomax","Lucas","Lincoln","Lowton","Lynch","Lawson","Leighton","Lowe"
    "McAlpine","Morris","Masterson","Maple","Merson","Mason","Miller","McDonald","Morgan","Moore","Moss","Mortimer"
    "McGrath","Meredith","Major","Marsh","Metcalf","Mattox","Murphy","Martin","Murray","Mitchell","Mills","Morse"
    "Mitchell"
    "Newman","Nelson","Naylor","Neville","Nicholls","Noble","Norris","Newton"
    "Oldman","Oakes","Osborn","O'Connor","Ogden","Owen"
    "Pilkington","Pyrodish","Potter","Peck","Pauling","Pepper","Power","Phillips","Pollard","Porter","Pearce"
    "Parker","Palmer","Payne","Price","Parsons","Powell","Pearson"
    "Quist","Queen","Quinn","Quail"
    "Rogers","Read","Rex","Rolfe","Randal","Roberts","Richards","Rayner","Ryan","Russell"
    "Reynolds","Rowland","Rudd","Ross","Robinson","Ravenscroft","Randall","Root","Reese"
    "Stewart","Smythe","Simpson","Simkins","Samson","Steele","Sinclair","Silver","Shelton","Sullivan"
    "Standing","Sparrow","Squire","Stevens","Stone","Swann","Scott","Sutton","Simpson","Shaw","Sutton"
    "Talbot","Tiller","Thomas","Tomkins","Towers","Taylor","Thaxter","Thompson","Thornton","Todd"
    "Travers","Turner","Tyler","Tonks","Trumble"
    "Unwin","Underwood","Underhill"
    "Vector","Vine","Vaughan","Vincent"
    "Watkins","Wells","Waters","Wolf","Winter","Washburn","Wright","Walker","Wood","Ward","Wakefield","Walker"
    "Wallace","Watson","Weaver","Webb","Williams","Whiting","Wilkinson","Wilson","Woodgate","White","Wyndham","Walsh"
    "Young","Yates","York"
  ];

  // Company tags - some appear more than once to raise their chances of being selected.
  local co_ai_tag = [
    " Express"," Express"," Rail"," Rail"," Rail"," Railways"," Railways"," Light Rail"
    " Transport"," Transport"," Transport"," Transporters"," Transportation"," Tankers"," Tankers"
    " Motors"," Coach Co"," Coaches"," Haulage"," Trucks"," Trucking"," Trains"," Trains"," Train Co"," Services"
    " Bus Company"," Buses"," Buses"," Inc"," Incorporated"," PLC"," Aero"," Wheels"," Ltd"," Ltd"
    " Freight"," Freight"," Logistics"," Movers"," Distribution"," Consortium"," Ventures"," Trust"
    " Aviation"," Trams"," Metro"," Containers"," Shipping"," Carriers"," Carriage"," Juggernauts"
    " Couriers"," Maritime"," Road Haulage"," Roadfreight"," Railfreight"," Hauliers"," Roadliners"
    " Group"," Group"," Dispatch"," Company"," Lines"," Enterprises"," Corporation"," Corp"," Intercity"
    " Heavy Freight"," Light Haulage"

    // These names won't go with certain formats so need to be skipped.
    // They must be the last 4 here, don't move them or add anything after them.
    " & Brothers"," & Co"," & Son"," & Sons"
  ];

  // First names - currently male only but perhaps female names should be added?
  local co_ai_first = [
    "Andrew","Alan","Albert","Arthur","Alex","Angus","Anthony","Adam"
    "Barry","Bruce","Boris","Barnaby","Ben","Barney"
    "Carl","Chris","Charles","Colin","Conrad","Cyril"
    "Daniel","Denzil","Derek","Desmond","Douglas","Darren","Dave","Earl","Eric","Edward","Edgar"
    "Frank","Fred","Gareth","Gavin","George","Gerald","Graham","Harold","Harry","Horace","Ivan","Ivor","Ian"
    "Jack","James","Jason","Jeff","Jim","John","Joseph","Julian"
    "Keith","Kenneth","Larry","Leonard","Liam","Leopold","Lionel"
    "Mark","Maurice","Michael","Matthew","Malcolm","Marvin","Monty"
    "Neville","Nigel","Oswald","Oscar","Oliver","Paddy","Peter","Phillip","Paul","Percival","Quintin"
    "Ralph","Robert","Roy","Roger","Rufus","Rupert","Ross","Robin","Reg"
    "Stuart","Simon","Sam","Scott","Stephen","Steve","Sean","Stanley","Sidney"
    "Terry","Theo","Tom","Tony","Trevor","Tyrone"
    "Vernon","Victor","Wayne","Wilfred","William","Zachary","Zane"
  ];

  // Logo identifiers - places and general names
  local co_ai_logo = [
    "Imperial","Velvet","Grand","Luxor","Luxury","Broadway","Plaza","Ritz","Empire","Stadium"
    "Ambassador","Britannia","Fairmont","Galaxy","Hilton","Hyatt","Metropole","Madison"
    "Abbey","Bridge","Castle","Court","Crescent","Grange","Grove","Haven","Mansion","Palace"
    "Paradise","Regency","Royal","Regal","Parkway","Parade","Riverside","Summit","Valley"
    "Atomic","Apollo","Dream","Riverside","Future"
    "Leopard","Lion","Tiger","Panther","Lynx","Mammoth","Condor","Eagle"
    "Blue","Orange","Red","Purple","Golden","Yellow","Diamond","Emerald","Opal","Scarlet","Azure","Ruby"
    "Sceptre","Executive","Crown","Noble","Sovereign","Majestic"
    "Liberty","Liquid","Quality","Raven","Power","Trust","Rocket"
    "Iron","Steel","Platinum"
    "Network","Atlas","First Choice","Target","Universal","Titan","Invincible","Independant","Perpetual"
    "Supreme","Ultimate","Tower","Premium","Capital","Choice","Prime","A1","Premier"
    "Paragon","Crystal","Rainbow","Stellar","Sphere","Pyramid","Triangle","Hexagon"
    "Union","Estate","Paramount","Corona","Horizon","Vortex","Ajax"
    "Mars","Venus","Mercury","Jupiter","Saturn","Neptune","Pluto","Moonbeam"
    "Sky","Comet","Meteor","Cosmic","Star","Planet","Sunbeam","Sunshine"
    "Lightning","Spirit","Zodiac","Rapid","Swift","Quicksilver","Arrow","Olympic"
    "Orion","Polaris","Gemini","Aquarius","Celtic","Aurora","Warrior"
    "National","International","Global","Worldwide","Globe","Equator","Everest","Andes"
    "Eastern","Western","Northern","Southern","Central","Midland","Highland","Island"
    "NorthEastern","NorthWestern","SouthEastern","SouthWestern","East Coast","West Coast","Lowland"
  ];

  // Letters for initials
  local co_ai_letters = [
    "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
  ];

  // generate a random number to select which type of name is produced.
  local rx = (AIBase.RandRange(13)) + 1

  // rx = 3;   // used to test a particular format.
  // AILog.Info("Format: " + rx);

  // show quantities of each group. Debug use only
  // AILog.Info("Counts:  Names " + co_ai_name.len() + " - First " + co_ai_first.len() + " - Tag   " + co_ai_tag.len() + " - Logo  " + co_ai_logo.len() );

  // Now pick the right block depending on the value of rx. Some blocks have multiple chances.
  // All blocks pick a name then test it for uniqueness. If not unique, they try again and again.

  switch ( rx ) {

    // name + tag
    case 1:
    case 2:

      local i = AIBase.RandRange(co_ai_name.len());
      local j = AIBase.RandRange(co_ai_tag.len());

      while (!AICompany.SetName(co_ai_name[i] + co_ai_tag[j])) {
        i = AIBase.RandRange(co_ai_name.len());
        j = AIBase.RandRange(co_ai_tag.len());
      }
    break;

    // 3 initials + tag
    case 3:

      local k1 = AIBase.RandRange(co_ai_letters.len());
      local k2 = AIBase.RandRange(co_ai_letters.len());
      local k3 = AIBase.RandRange(co_ai_letters.len());

              // avoid last 4 tag names as they don't fit well with this format
      local j = AIBase.RandRange(co_ai_tag.len()-4);

      while (!AICompany.SetName(co_ai_letters[k1] + co_ai_letters[k2] + co_ai_letters[k3] + co_ai_tag[j])) {
        k1 = AIBase.RandRange(co_ai_letters.len());
        k2 = AIBase.RandRange(co_ai_letters.len());
        k3 = AIBase.RandRange(co_ai_letters.len());
        j = AIBase.RandRange(co_ai_tag.len()-4);
      }
    break;

    // name-name + tag
    case 4:
    case 5:

      local i = AIBase.RandRange(co_ai_name.len());
      local k = AIBase.RandRange(co_ai_name.len());

      // avoid last 4 tag names as they don't fit well with this format
      local j = AIBase.RandRange(co_ai_tag.len()-4);

      while (!AICompany.SetName(co_ai_name[i] +"-" + co_ai_name[k] + co_ai_tag[j])) {
        i = AIBase.RandRange(co_ai_name.len());
        k = AIBase.RandRange(co_ai_name.len());
        j = AIBase.RandRange(co_ai_tag.len()-4);
      }
    break;

    // first + name + tag
    case 6:
    case 7:

      local i = AIBase.RandRange(co_ai_first.len());
      local k = AIBase.RandRange(co_ai_name.len());
      local j = AIBase.RandRange(co_ai_tag.len());

      while (!AICompany.SetName(co_ai_first[i] +" " + co_ai_name[k] + co_ai_tag[j])) {
        i = AIBase.RandRange(co_ai_first.len());
        k = AIBase.RandRange(co_ai_name.len());
        j = AIBase.RandRange(co_ai_tag.len());
      }
    break;

    // 2 initials + tag
    case 8:

      local k1 = AIBase.RandRange(co_ai_letters.len());
      local k2 = AIBase.RandRange(co_ai_letters.len());
      local j = AIBase.RandRange(co_ai_tag.len());

      while (!AICompany.SetName(co_ai_letters[k1] + co_ai_letters[k2] + co_ai_tag[j])) {
        k1 = AIBase.RandRange(co_ai_letters.len());
        k2 = AIBase.RandRange(co_ai_letters.len());
        j = AIBase.RandRange(co_ai_tag.len());
      }
    break;

    // initial + name + tag
    case 9:
    case 10:

      local i = AIBase.RandRange(co_ai_letters.len());
      local k = AIBase.RandRange(co_ai_name.len());
      local j = AIBase.RandRange(co_ai_tag.len());

      while (!AICompany.SetName(co_ai_letters[i] +". " + co_ai_name[k] + co_ai_tag[j])) {
        i = AIBase.RandRange(co_ai_letters.len());
        k = AIBase.RandRange(co_ai_name.len());
        j = AIBase.RandRange(co_ai_tag.len());
      }
    break;

    // logo + tag
    case 11:
    case 12:

      local i = AIBase.RandRange(co_ai_logo.len());

      // avoid last 4 tag names as they don't fit well with this format
      local j = AIBase.RandRange(co_ai_tag.len()-4);

      while (!AICompany.SetName(co_ai_logo[i] + co_ai_tag[j])) {
              i = AIBase.RandRange(co_ai_logo.len());
        j = AIBase.RandRange(co_ai_tag.len()-4);
      }
    break;

    // town name + tag
    case 13:
      // Get the name of the town given
      local town_name = AITown.GetName(town_id);

      // avoid last 4 tag names as they don't fit well with this format
      local j = AIBase.RandRange(co_ai_tag.len()-4);

      while (!AICompany.SetName(town_name + co_ai_tag[j])) {
        j = AIBase.RandRange(co_ai_tag.len()-4);
      }
    break;

    // More name designs can go here. Remember to increase rx range and add "case xx:" references.


    // incorrect random range, so set name to "Unnamed nnn" as a warning. We should normally never get here.
    default:
      local j = AIBase.RandRange(999) + 1
      AICompany.SetName("Unnamed " + j);
    break;
  }
}
