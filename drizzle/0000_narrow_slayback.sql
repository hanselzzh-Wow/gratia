CREATE TABLE `assignments` (
	`id` text PRIMARY KEY NOT NULL,
	`wish_id` text NOT NULL,
	`provider_name` text NOT NULL,
	`provider_contact` text NOT NULL,
	`status` text DEFAULT 'offered' NOT NULL,
	`note` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`accepted_at` integer,
	`delivered_at` integer,
	FOREIGN KEY (`wish_id`) REFERENCES `wishes`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `assignments_wish_created_idx` ON `assignments` (`wish_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `deliverables` (
	`id` text PRIMARY KEY NOT NULL,
	`wish_id` text NOT NULL,
	`assignment_id` text,
	`kind` text NOT NULL,
	`url` text NOT NULL,
	`note` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`wish_id`) REFERENCES `wishes`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`assignment_id`) REFERENCES `assignments`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE INDEX `deliverables_wish_created_idx` ON `deliverables` (`wish_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `wish_events` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`wish_id` text NOT NULL,
	`event_type` text NOT NULL,
	`from_status` text,
	`to_status` text,
	`actor` text NOT NULL,
	`note` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`wish_id`) REFERENCES `wishes`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `wish_events_wish_created_idx` ON `wish_events` (`wish_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `wishes` (
	`id` text PRIMARY KEY NOT NULL,
	`public_code` text NOT NULL,
	`requester_name` text NOT NULL,
	`contact` text NOT NULL,
	`city` text NOT NULL,
	`landmark` text NOT NULL,
	`occasion` text NOT NULL,
	`message` text NOT NULL,
	`delivery_type` text NOT NULL,
	`deadline_text` text NOT NULL,
	`reward_fen` integer DEFAULT 1800 NOT NULL,
	`publish_fee_fen` integer DEFAULT 500 NOT NULL,
	`status` text DEFAULT 'pending_review' NOT NULL,
	`moderation_note` text,
	`source` text DEFAULT 'web' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `wishes_public_code_unique` ON `wishes` (`public_code`);--> statement-breakpoint
CREATE INDEX `wishes_status_created_idx` ON `wishes` (`status`,`created_at`);--> statement-breakpoint
CREATE INDEX `wishes_city_status_idx` ON `wishes` (`city`,`status`);