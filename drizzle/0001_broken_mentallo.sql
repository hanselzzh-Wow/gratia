CREATE TABLE `wish_responses` (
	`id` text PRIMARY KEY NOT NULL,
	`wish_id` text NOT NULL,
	`responder_name` text NOT NULL,
	`responder_contact` text NOT NULL,
	`note` text,
	`status` text DEFAULT 'pending' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`wish_id`) REFERENCES `wishes`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `wish_responses_wish_contact_unique` ON `wish_responses` (`wish_id`,`responder_contact`);--> statement-breakpoint
CREATE INDEX `wish_responses_wish_created_idx` ON `wish_responses` (`wish_id`,`created_at`);