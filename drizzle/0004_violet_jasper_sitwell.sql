CREATE TABLE `providers` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`contact` text NOT NULL,
	`city` text NOT NULL,
	`landmarks` text NOT NULL,
	`availability_note` text,
	`status` text DEFAULT 'available' NOT NULL,
	`completed_count` integer DEFAULT 0 NOT NULL,
	`last_assigned_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `providers_contact_unique` ON `providers` (`contact`);--> statement-breakpoint
CREATE INDEX `providers_city_status_idx` ON `providers` (`city`,`status`);--> statement-breakpoint
ALTER TABLE `assignments` ADD `provider_id` text REFERENCES providers(id);