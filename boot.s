/* Déclaration des constantes pour l'en-tête multiboot. */
.set ALIGN,    1<<0             /* aligne les modules chargés sur les limites de page */
.set MEMINFO,  1<<1             /* fournit une carte mémoire */
.set FLAGS,    ALIGN | MEMINFO  /* ceci est le champ 'flag' de Multiboot */
.set MAGIC,    0x1BADB002       /* le 'nombre magique' permet au bootloader de trouver l'en-tête */
.set CHECKSUM, -(MAGIC + FLAGS) /* somme de contrôle de ce qui précède, pour prouver que nous sommes multiboot */


/* 
Déclare un en-tête multiboot qui marque le programme comme un noyau. Ce sont des valeurs
magiques qui sont documentées dans le standard multiboot. Le bootloader recherchera
cette signature dans les premiers 8 Ko du fichier du noyau, alignée sur une limite de 32 bits.
La signature est dans sa propre section pour que l'en-tête puisse être forcé à se trouver
dans les premiers 8 Ko du fichier du noyau.
*/
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM


/*
Le standard multiboot ne définit pas la valeur du registre de pointeur de pile
(esp) et c'est au noyau de fournir une pile. Ceci alloue de l'espace pour une
petite pile en créant un symbole au bas de celle-ci, puis en allouant 16384
octets pour elle, et enfin en créant un symbole au sommet. La pile croît
vers le bas sur x86. La pile est dans sa propre section pour qu'elle puisse être marquée nobits,
ce qui signifie que le fichier du noyau est plus petit car il ne contient pas une
pile non initialisée. La pile sur x86 doit être alignée sur 16 octets selon le
standard ABI System V et ses extensions de facto. Le compilateur supposera que la
pile est correctement alignée et l'échec d'alignement de la pile entraînera un
comportement indéfini.
*/
.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 Ko
stack_top:


/*
Le script de liaison spécifie _start comme point d'entrée du noyau et le
bootloader sautera à cette position une fois que le noyau aura été chargé. Il
n'a pas de sens de retourner de cette fonction car le bootloader n'existe plus.
*/
.section .text
.global _start
.type _start, @function
_start:
	/*
	Le bootloader nous a chargés en mode protégé 32 bits sur une machine x86.
	Les interruptions sont désactivées. La pagination est désactivée. L'état du processeur
	est tel que défini dans le standard multiboot. Le noyau a le contrôle total
	du CPU. Le noyau ne peut utiliser que les fonctionnalités matérielles
	et tout code qu'il fournit dans son propre cadre. Il n'y a pas de fonction printf,
	à moins que le noyau ne fournisse son propre en-tête <stdio.h> et une
	implémentation de printf. Il n'y a pas de restrictions de sécurité, pas de
	protections, pas de mécanismes de débogage, seulement ce que le noyau fournit
	lui-même. Il a un pouvoir absolu et complet sur la
	machine.
	*/

	/*
	Pour configurer une pile, nous définissons le registre esp pour qu'il pointe vers le haut de la
	pile (car elle croît vers le bas sur les systèmes x86). Ceci est nécessairement fait
	en assembleur car des langages comme C ne peuvent pas fonctionner sans pile.
	*/
	mov $stack_top, %esp

	/*
	C'est un bon endroit pour initialiser l'état crucial du processeur avant que le
	noyau de haut niveau ne soit lancé. Il est préférable de minimiser l'environnement précoce
	où des fonctionnalités cruciales sont hors ligne. Notez que le
	processeur n'est pas encore entièrement initialisé : Des fonctionnalités telles que les instructions
	à virgule flottante et les extensions de jeu d'instructions ne sont pas encore initialisées.
	La GDT devrait être chargée ici. La pagination devrait être activée ici.
	Les fonctionnalités C++ telles que les constructeurs globaux et les exceptions nécessiteront
	également un support d'exécution pour fonctionner.
	*/

	/*
	Entrer dans le noyau de haut niveau. L'ABI exige que la pile soit alignée sur 16 octets
	au moment de l'instruction d'appel (qui ensuite pousse
	le pointeur de retour de taille 4 octets). La pile était initialement alignée sur 16 octets
	ci-dessus et nous avons poussé un multiple de 16 octets sur la
	pile depuis (poussé 0 octet jusqu'à présent), donc l'alignement a été
	préservé et l'appel est bien défini.
	*/
	call kernel_main

	/*
	Si le système n'a plus rien à faire, mettez l'ordinateur dans une
	boucle infinie. Pour ce faire :
	1) Désactivez les interruptions avec cli (clear interrupt enable dans eflags).
	   Elles sont déjà désactivées par le bootloader, donc ce n'est pas nécessaire.
	   Notez que vous pourriez plus tard activer les interruptions et retourner de
	   kernel_main (ce qui est en quelque sorte absurde à faire).
	2) Attendez la prochaine interruption avec hlt (instruction halt).
	   Comme elles sont désactivées, cela bloquera l'ordinateur.
	3) Sautez à l'instruction hlt s'il se réveille jamais en raison d'une
	   interruption non masquable ou en raison du mode de gestion du système.
	*/
	cli
1:	hlt
	jmp 1b

/*
Définir la taille du symbole _start à l'emplacement actuel '.' moins son début.
Ceci est utile lors du débogage ou lorsque vous implémentez le traçage des appels.
*/
.size _start, . - _start